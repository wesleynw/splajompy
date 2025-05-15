package main

import (
	"context"
	"log"
	"net/http"
	"os"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/joho/godotenv"
	"github.com/resend/resend-go/v2"

	db "splajompy.com/api/v2/internal/db/generated"
	"splajompy.com/api/v2/internal/handler"
	"splajompy.com/api/v2/internal/middleware"
	"splajompy.com/api/v2/internal/service"
)

func main() {
	ctx := context.Background()
	err := godotenv.Load()
	if err != nil {
		print("no .env present")
	}

	connString := os.Getenv("DB_CONNECTION_STRING")
	conn, err := pgxpool.New(ctx, connString)
	if err != nil {
		log.Fatalf("failed to connect to database: %v", err)
	}
	defer conn.Close()

	queries := db.New(conn)

	resentApiKey := os.Getenv("RESEND_API_KEY")
	resentClient := resend.NewClient(resentApiKey)

	s3Client, err := service.NewS3Client()
	if err != nil {
		log.Fatalf("failed to initialize s3 client: %v", err)
	}

	postService := service.NewPostService(queries, s3Client)
	commentService := service.NewCommentService(queries)
	userService := service.NewUserService(queries)
	notificationService := service.NewNotificationService(queries)
	authManager := service.NewAuthService(queries, resentClient)

	h := handler.NewHandler(*queries, postService, commentService, userService, notificationService, authManager)

	mux := http.NewServeMux()
	h.RegisterRoutes(mux)

	wrappedMux := middleware.Logger(mux)

	log.Printf("Server starting on port %d\n", 8080)
	if err := http.ListenAndServe(":8080", wrappedMux); err != nil {
		log.Fatalf("server failed to start: %v", err)
	}
}
