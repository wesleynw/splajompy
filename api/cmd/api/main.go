package main

import (
	"context"
	"github.com/exaring/otelpgx"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"log"
	"net/http"
	"os"
	"splajompy.com/api/v2/internal/db/queries"
	"splajompy.com/api/v2/internal/repositories"
	"splajompy.com/api/v2/internal/utilities"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/joho/godotenv"
	"github.com/resend/resend-go/v2"

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

	resentApiKey := os.Getenv("RESEND_API_KEY")
	resentClient := resend.NewClient(resentApiKey)

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

	postService := service.NewPostService(postRepository, userRepository, likeRepository, notificationsRepository, bucketRepository, resentClient)
	commentService := service.NewCommentService(commentRepository, postRepository, notificationsRepository, userRepository)
	userService := service.NewUserService(userRepository, notificationsRepository, resentClient)
	notificationService := service.NewNotificationService(notificationsRepository, postRepository, commentRepository)
	authManager := service.NewAuthService(userRepository, postRepository, bucketRepository, resentClient)

	h := handler.NewHandler(q, postService, commentService, userService, notificationService, authManager)

	mux := http.NewServeMux()
	h.RegisterRoutes(mux)

	wrappedHandler := middleware.AuthMiddleware(q)(mux)
	wrappedHandler = middleware.Logger(wrappedHandler)
	wrappedHandler = middleware.AppVersion(wrappedHandler)

	// Add HTTP instrumentation for the whole server.
	httpHandler := otelhttp.NewHandler(wrappedHandler, "/",
		otelhttp.WithSpanNameFormatter(func(operation string, r *http.Request) string {
			method := r.Method
			path := r.URL.Path
			if path == "" {
				path = "/"
			}
			return method + " " + path
		}),
	)

	log.Printf("Server starting on port %d\n", 8080)
	if err := http.ListenAndServe(":8080", httpHandler); err != nil {
		log.Fatalf("server failed to start: %v", err)
	}
}
