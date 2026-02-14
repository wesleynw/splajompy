package main

import (
	"context"
	"log"
	"net/http"
	"os"

	"github.com/exaring/otelpgx"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	semconv "go.opentelemetry.io/otel/semconv/v1.39.0"
	"go.opentelemetry.io/otel/trace"
	"splajompy.com/api/v2/internal/db/queries"
	"splajompy.com/api/v2/internal/repositories"
	"splajompy.com/api/v2/internal/utilities"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/joho/godotenv"
	"github.com/resend/resend-go/v3"

	"splajompy.com/api/v2/internal/handler"
	"splajompy.com/api/v2/internal/middleware"
	"splajompy.com/api/v2/internal/service"
)

func main() {
	ctx := context.Background()

	err := godotenv.Load()
	if err != nil {
		log.Printf("no .env file present")
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

	s3Client, err := service.NewS3Client()
	if err != nil {
		log.Fatalf("failed to initialize s3 client: %v", err)
	}

	bucketRepository := repositories.NewS3BucketRepository(s3Client)

	postRepository := repositories.NewDBPostRepository(q)
	userRepository := repositories.NewDBUserRepository(q)
	notificationsRepository := repositories.NewDBNotificationRepository(q)
	commentRepository := repositories.NewDBCommentRepository(q)
	likeRepository := repositories.NewDBLikeRepository(q)
	statsRepository := repositories.NewDBStatsRepository(q)

	postService := service.NewPostService(postRepository, userRepository, likeRepository, notificationsRepository, bucketRepository, resendClient)
	commentService := service.NewCommentService(commentRepository, postRepository, notificationsRepository, userRepository, likeRepository)
	userService := service.NewUserService(userRepository, notificationsRepository, resendClient)
	notificationService := service.NewNotificationService(notificationsRepository, postRepository, commentRepository, userRepository)
	authManager := service.NewAuthService(userRepository, postRepository, bucketRepository, resendClient)
	statsService := service.NewStatsService(statsRepository)
	wrappedService := service.NewWrappedService(q, *postService)

	h := handler.NewHandler(q, postService, commentService, userService, notificationService, authManager, statsService, wrappedService)

	mux := http.NewServeMux()

	authMiddleware := middleware.AuthMiddleware(q)
	h.RegisterRoutes(mux.HandleFunc, authMiddleware)
	h.RegisterPublicRoutes(mux.HandleFunc)

	routedMux := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		mux.ServeHTTP(w, r)
		if r.Pattern != "" {
			span := trace.SpanFromContext(r.Context())
			span.SetName(r.Pattern)
			span.SetAttributes(semconv.HTTPRoute(r.Pattern))
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
