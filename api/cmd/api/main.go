package main

import (
	"context"
	"log"
	"log/slog"
	"os"

	"github.com/exaring/otelpgx"
	"splajompy.com/api/v2/internal/apns"
	"splajompy.com/api/v2/internal/auth"
	"splajompy.com/api/v2/internal/bucket"
	"splajompy.com/api/v2/internal/comment"
	"splajompy.com/api/v2/internal/db/queries"
	"splajompy.com/api/v2/internal/email"
	"splajompy.com/api/v2/internal/like"
	"splajompy.com/api/v2/internal/notification"
	"splajompy.com/api/v2/internal/post"
	"splajompy.com/api/v2/internal/server"
	"splajompy.com/api/v2/internal/stats"
	"splajompy.com/api/v2/internal/user"
	"splajompy.com/api/v2/internal/utilities"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/joho/godotenv"
	"github.com/resend/resend-go/v3"
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
	if err := otelpgx.RecordStats(conn); err != nil {
		log.Fatalf("unable to record database stats: %v", err)
	}
	defer conn.Close()

	q := queries.New(conn)

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
	notificationsRepository := notification.NewNotificationStore(q)
	commentRepository := comment.NewStore(q)
	likeRepository := like.NewStore(q)
	statsRepository := stats.NewStore(q)

	privateKeyString := os.Getenv("APN_PRIVATE_KEY")
	keyId := os.Getenv("APN_KEY_ID")
	teamId := os.Getenv("APN_TEAM_ID")
	apnClient := apns.NewClient(apns.NewToken(privateKeyString, keyId, teamId))

	notificationService := notification.NewService(notificationsRepository, postRepository, commentRepository, userRepository, bucketRepository, *apnClient)

	postService := post.NewService(postRepository, userRepository, likeRepository, *notificationService, bucketRepository, resendClient)
	postHandler := post.NewHandler(postService)
	commentService := comment.NewService(commentRepository, postRepository, *notificationService, userRepository, likeRepository, bucketRepository)
	commentHandler := comment.NewHandler(commentService)
	userService := user.NewUserService(userRepository, *notificationService, resendClient)
	userHandler := user.NewHandler(userService)
	notificationHandler := notification.NewHandler(notificationService)
	notificationConnectHandler := notification.NewConnectHandler(notificationService)
	emailClient := email.NewResendEmailClient(resendClient)
	authService := auth.NewService(userRepository, postRepository, bucketRepository, emailClient)
	authHandler := auth.NewHandler(authService)
	statsService := stats.NewService(statsRepository)
	statsHandler := stats.NewHandler(statsService)
	statsConnectHandler := stats.NewConnectHandler(statsService)

	httpServer, mux := server.NewServer()

	server.RegisterREST(mux, q, postHandler, commentHandler, userHandler, notificationHandler, authHandler, statsHandler)
	server.RegisterRPC(mux, q, notificationConnectHandler, statsConnectHandler)

	log.Printf("Server starting on %s\n", httpServer.Addr)
	if err := httpServer.ListenAndServe(); err != nil {
		log.Fatalf("server failed to start: %v", err)
	}
}
