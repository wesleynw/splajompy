package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"splajompy.com/api/v2/internal/db/queries"
	"splajompy.com/api/v2/internal/repositories"

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

	connString := os.Getenv("DB_CONNECTION_STRING")
	conn, err := pgxpool.New(ctx, connString)
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
	userService := service.NewUserService(userRepository, notificationsRepository)
	notificationService := service.NewNotificationService(notificationsRepository, postRepository, commentRepository)
	authManager := service.NewAuthService(userRepository, postRepository, bucketRepository, resentClient)

	h := handler.NewHandler(q, postService, commentService, userService, notificationService, authManager)

	mux := http.NewServeMux()
	h.RegisterRoutes(mux)

	wrappedMux := middleware.Logger(mux)

	log.Printf("Server starting on port %d\n", 8080)
	if err := http.ListenAndServe(":8080", wrappedMux); err != nil {
		log.Fatalf("server failed to start: %v", err)
	}
}
