package main

import (
	"context"
	"log"
	"log/slog"
	"net/http"
	"os"

	"github.com/exaring/otelpgx"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	semconv "go.opentelemetry.io/otel/semconv/v1.39.0"
	"go.opentelemetry.io/otel/trace"
	"splajompy.com/api/v2/internal/apns"
	"splajompy.com/api/v2/internal/auth"
	"splajompy.com/api/v2/internal/bucket"
	"splajompy.com/api/v2/internal/comment"
	"splajompy.com/api/v2/internal/db/queries"
	"splajompy.com/api/v2/internal/like"
	"splajompy.com/api/v2/internal/notification"
	"splajompy.com/api/v2/internal/post"
	"splajompy.com/api/v2/internal/stats"
	"splajompy.com/api/v2/internal/user"
	"splajompy.com/api/v2/internal/utilities"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/joho/godotenv"
	"github.com/resend/resend-go/v3"

	"splajompy.com/api/v2/internal/handler"
	"splajompy.com/api/v2/internal/middleware"
)

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
	defer conn.Close()

	q := queries.New(conn)

	resendApiKey := os.Getenv("RESEND_API_KEY")
	resendClient := resend.NewClient(resendApiKey)

	s3Client, err := bucket.NewS3Client()
	if err != nil {
		log.Fatalf("failed to initialize s3 client: %v", err)
	}

	bucketRepository := bucket.NewS3BucketRepository(s3Client)

	postRepository := post.NewDBPostRepository(q)
	userRepository := user.NewUserRepository(q)
	notificationsRepository := notification.NewNotificationStore(q)
	commentRepository := comment.NewStore(q)
	likeRepository := like.NewStore(q)
	statsRepository := stats.NewStore(q)

	apnClient := apns.NewClient(apns.NewToken())

	notificationService := notification.NewService(notificationsRepository, postRepository, commentRepository, userRepository, bucketRepository, *apnClient)

	postService := post.NewService(postRepository, userRepository, likeRepository, *notificationService, bucketRepository, resendClient)
	postHandler := post.NewHandler(postService)
	commentService := comment.NewService(commentRepository, postRepository, *notificationService, userRepository, likeRepository, bucketRepository)
	commentHandler := comment.NewHandler(commentService)
	userService := user.NewUserService(userRepository, *notificationService, resendClient)
	userHandler := user.NewHandler(userService)
	notificationHandler := notification.NewHandler(notificationService)
	authService := auth.NewService(userRepository, postRepository, bucketRepository, resendClient)
	authHandler := auth.NewHandler(authService)
	statsService := stats.NewService(statsRepository)
	statsHandler := stats.NewHandler(statsService)

	h := handler.NewHandler(postHandler, commentHandler, userHandler, notificationHandler, authHandler, statsHandler)

	mux := http.NewServeMux()

	authMiddleware := middleware.AuthMiddleware(q)
	h.RegisterRoutes(mux.HandleFunc, authMiddleware)

	routedMux := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
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

	wrappedHandler := middleware.Logger(routedMux)
	wrappedHandler = middleware.AppVersion(wrappedHandler)

	httpHandler := otelhttp.NewHandler(wrappedHandler, "/")

	log.Printf("Server starting on port %d\n", 8080)
	if err := http.ListenAndServe(":8080", httpHandler); err != nil {
		log.Fatalf("server failed to start: %v", err)
	}
}
