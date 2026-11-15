package main

import (
	"context"
	"log"
	"log/slog"
	"net/http"
	"os"
	"time"

	"connectrpc.com/connect/v2"
	"connectrpc.com/connect/v2/connecthttp"
	"connectrpc.com/validate"
	"github.com/exaring/otelpgx"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	semconv "go.opentelemetry.io/otel/semconv/v1.40.0"
	"go.opentelemetry.io/otel/trace"
	"splajompy.com/api/v2/gen/splajompy/v1/splajompyv1connect"
	"splajompy.com/api/v2/internal/apns"
	"splajompy.com/api/v2/internal/auth"
	"splajompy.com/api/v2/internal/bucket"
	"splajompy.com/api/v2/internal/comment"
	"splajompy.com/api/v2/internal/db/queries"
	"splajompy.com/api/v2/internal/interceptor"
	"splajompy.com/api/v2/internal/like"
	"splajompy.com/api/v2/internal/middleware"
	"splajompy.com/api/v2/internal/notification"
	"splajompy.com/api/v2/internal/post"
	"splajompy.com/api/v2/internal/routes"
	"splajompy.com/api/v2/internal/stats"
	"splajompy.com/api/v2/internal/user"
	"splajompy.com/api/v2/internal/utilities"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/joho/godotenv"
	"github.com/resend/resend-go/v3"
)

// maxRPCRequestBytes limits each decompressed request message to 4 MiB.
const maxRPCRequestBytes = 4 * 1024 * 1024

func main() {
	ctx := context.Background()

	err := godotenv.Load()
	if err != nil {
		slog.InfoContext(ctx, "no .env file present")
	}

	// Setup OpenTelemetry SDK
	shutdown, err := utilities.SetupOTelSDK(ctx)
	if err != nil {
		log.Fatalf("failed to setup OpenTelemetry SDK: %v", err)
	}
	defer func() {
		if err := shutdown(ctx); err != nil {
			log.Printf("failed to shutdown OpenTelemetry SDK: %v", err)
		}
	}()
	utilities.InitializeProfiling()

	connString := os.Getenv("DB_CONNECTION_STRING")
	cfg, err := pgxpool.ParseConfig(connString)
	if err != nil {
		log.Fatalf("failed to parse config: %v", err)
	}

	// instrument the sql driver
	cfg.ConnConfig.Tracer = otelpgx.NewTracer()
	conn, err := pgxpool.NewWithConfig(ctx, cfg)
	if err != nil {
		log.Fatalf("failed to connect to database: %v", err)
	}
	if err := otelpgx.RecordStats(conn); err != nil {
		log.Fatalf("unable to record database stats: %v", err)
	}
	defer conn.Close()

	q := queries.New(conn)

	notificationConfig := cfg.ConnConfig
	// LISTEN requires a direct or session-pooled connection.
	if listenURL := os.Getenv("DB_LISTEN_CONNECTION_STRING"); listenURL != "" {
		notificationConfig, err = pgx.ParseConfig(listenURL)
		if err != nil {
			log.Fatal("invalid notification database configuration")
		}
	}

	resendApiKey := os.Getenv("RESEND_API_KEY")
	resendClient := resend.NewClient(resendApiKey)

	s3Client, err := bucket.NewS3Client()
	if err != nil {
		log.Fatalf("failed to initialize s3 client: %v", err)
	}

	cloudfrontSigner, err := bucket.NewCloudfrontSigner()
	if err != nil {
		log.Fatalf("failed to initialize cloudfront signer: %v", err)
	}
	bucketRepository := bucket.NewS3BucketRepository(s3Client, cloudfrontSigner)

	postRepository := post.NewDBPostRepository(q)
	userRepository := user.NewUserRepository(q)
	notificationsRepository := notification.NewNotificationStore(q, notificationConfig)
	commentRepository := comment.NewStore(q)
	likeRepository := like.NewStore(q)
	statsRepository := stats.NewStore(q)

	privateKeyString := os.Getenv("APN_PRIVATE_KEY")
	keyId := os.Getenv("APN_KEY_ID")
	teamId := os.Getenv("APN_TEAM_ID")
	apnClient := apns.NewClient(apns.NewToken(privateKeyString, keyId, teamId))

	notificationService := notification.NewService(notificationsRepository, postRepository, commentRepository, userRepository, bucketRepository, *apnClient)

	postService := post.NewService(postRepository, userRepository, likeRepository, notificationService, bucketRepository, resendClient)
	postHandler := post.NewHandler(postService)
	commentService := comment.NewService(commentRepository, postRepository, notificationService, userRepository, likeRepository, bucketRepository)
	commentHandler := comment.NewHandler(commentService)
	userService := user.NewUserService(userRepository, notificationService, resendClient)
	userHandler := user.NewHandler(userService)
	notificationHandler := notification.NewHandler(notificationService)
	notificationConnectHandler := notification.NewConnectHandler(notificationService)
	authService := auth.NewService(userRepository, postRepository, bucketRepository, resendClient)
	authHandler := auth.NewHandler(authService)
	statsService := stats.NewService(statsRepository)
	statsHandler := stats.NewHandler(statsService)

	mux := http.NewServeMux()
	routes.RegisterREST(mux, q, postHandler, commentHandler, userHandler, notificationHandler, authHandler, statsHandler)

	rpcServer := connect.NewServer(interceptor.AppVersion, interceptor.Auth(q), validate.NewServerInterceptor())
	splajompyv1connect.RegisterNotificationServiceHandler(rpcServer, notificationConnectHandler)
	connecthttp.Mount(mux, rpcServer, connecthttp.WithReadMaxBytes(maxRPCRequestBytes))

	routeTelemetryHandler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		mux.ServeHTTP(w, r)
		span := trace.SpanFromContext(r.Context())
		if r.Pattern != "" {
			span.SetName(r.Pattern)
			span.SetAttributes(semconv.HTTPRoute(r.Pattern))
			if labeler, ok := otelhttp.LabelerFromContext(r.Context()); ok {
				labeler.Add(semconv.HTTPRoute(r.Pattern))
			}
		} else {
			span.SetName(r.Method + " " + r.URL.Path)
		}
	})

	loggingHandler := middleware.Logger(routeTelemetryHandler)

	httpHandler := otelhttp.NewHandler(loggingHandler, "/")
	httpServer := &http.Server{
		Addr:              ":8080",
		Handler:           httpHandler,
		Protocols:         new(http.Protocols),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       30 * time.Second,
		// WriteTimeout covers the whole response, including streaming RPCs.
		WriteTimeout: 6 * time.Minute,
		IdleTimeout:  time.Minute,
	}
	httpServer.Protocols.SetHTTP1(true)
	httpServer.Protocols.SetUnencryptedHTTP2(true)

	log.Printf("Server starting on port %d\n", 8080)
	if err := httpServer.ListenAndServe(); err != nil {
		log.Fatalf("server failed to start: %v", err)
	}
}
