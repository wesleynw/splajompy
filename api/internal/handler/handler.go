package handler

import (
	"errors"
	"net/http"
	"splajompy.com/api/v2/internal/db/queries"
	"strconv"

	"splajompy.com/api/v2/internal/service"
)

type Handler struct {
	queries             queries.Querier
	postService         *service.PostService
	commentService      *service.CommentService
	userService         *service.UserService
	notificationService *service.NotificationService
	authService         *service.AuthService
}

func NewHandler(queries queries.Querier,
	postService *service.PostService,
	commentService *service.CommentService,
	userService *service.UserService,
	notificationService *service.NotificationService,
	authService *service.AuthService) *Handler {
	return &Handler{
		queries:             queries,
		postService:         postService,
		commentService:      commentService,
		userService:         userService,
		notificationService: notificationService,
		authService:         authService,
	}
}

func (h *Handler) RegisterRoutes(mux *http.ServeMux) {
	// auth
	mux.HandleFunc("POST /register", h.Register)
	mux.HandleFunc("POST /login", h.Login)
	mux.HandleFunc("POST /otc/generate", h.GenerateOTC)
	mux.HandleFunc("POST /otc/verify", h.VerifyOTC)
	mux.HandleFunc("POST /account/delete", h.DeleteAccount)

	// posts
	mux.HandleFunc("GET /post/presignedUrl", h.GetPresignedUrl)
	mux.HandleFunc("POST /post/new", h.CreateNewPost)
	mux.HandleFunc("GET /post/{id}", h.GetPostById)
	mux.HandleFunc("GET /user/{id}/posts", h.GetPostsByUserId)
	mux.HandleFunc("DELETE /post/{id}", h.DeletePostById)
	mux.HandleFunc("POST /post/{id}/report", h.ReportPost)

	// follow
	mux.HandleFunc("POST /follow/{user_id}", h.FollowUser)
	mux.HandleFunc("DELETE /follow/{user_id}", h.UnfollowUser)

	mux.HandleFunc("POST /user/profile", h.UpdateProfile)

	// likes
	mux.HandleFunc("POST /post/{id}/liked", h.AddPostLike)
	mux.HandleFunc("DELETE /post/{id}/liked", h.RemovePostLike)

	// notifications
	mux.HandleFunc("GET /notifications", h.GetAllNotificationByUserId)
	mux.HandleFunc("POST /notifications/markRead", h.MarkAllNotificationsAsRead)
	mux.HandleFunc("POST /notifications/{id}/markRead", h.MarkNotificationAsReadById)
	mux.HandleFunc("GET /notifications/hasUnread", h.HasUnreadNotifications)
	mux.HandleFunc("GET /notifications/unreadCount", h.GetUnreadNotificationCount)

	// comments
	mux.HandleFunc("POST /post/{post_id}/comment", h.AddCommentToPostById)
	mux.HandleFunc("POST /post/{post_id}/comment/{comment_id}/liked", h.AddCommentLike)
	mux.HandleFunc("DELETE /post/{post_id}/comment/{comment_id}/liked", h.RemoveCommentLike)

	// blocking
	mux.HandleFunc("POST /user/{user_id}/block", h.BlockUser)
	mux.HandleFunc("DELETE /user/{user_id}/block", h.UnblockUser)

	mux.HandleFunc("GET /user/{id}", h.GetUserById)
	mux.HandleFunc("GET /posts/following", h.GetPostsByFollowing)
	mux.HandleFunc("GET /posts/all", h.GetAllPosts)
	mux.HandleFunc("GET /posts/mutual", h.GetMutualFeed)

	mux.HandleFunc("GET /users/search", h.SearchUsers)

	// comments
	mux.HandleFunc("GET /post/{id}/comments", h.GetCommentsByPost)
}

func (h *Handler) GetIntPathParam(r *http.Request, paramName string) (int, error) {
	paramString := r.PathValue(paramName)
	if paramString == "" {
		return 0, errors.New("missing url parameter")
	}
	param, err := strconv.Atoi(paramString)
	if err != nil {
		return 0, errors.New("cannot parse url parameter")
	}

	return param, nil
}
