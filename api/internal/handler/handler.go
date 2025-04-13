package handler

import (
	"encoding/json"
	"errors"
	"net/http"
	"strconv"

	db "splajompy.com/api/v2/internal/db/generated"
	"splajompy.com/api/v2/internal/service"
)

type Handler struct {
	queries               *db.Queries
	postService           *service.PostService
	commentService        *service.CommentService
	userService           *service.UserService
	notifificationService *service.NotificationService
	authService           *service.AuthService
}

func NewHandler(queries db.Queries,
	postService *service.PostService,
	commentService *service.CommentService,
	userService *service.UserService,
	notificationService *service.NotificationService,
	authService *service.AuthService) *Handler {
	return &Handler{
		queries:               &queries,
		postService:           postService,
		commentService:        commentService,
		userService:           userService,
		notifificationService: notificationService,
		authService:           authService,
	}
}

func (h *Handler) RegisterRoutes(mux *http.ServeMux) {
	// mux.HandleFunc("POST /register", h.register)
	mux.HandleFunc("POST /login", h.Login)
	mux.HandleFunc("POST /otc/generate", h.GenerateOTC)
	mux.HandleFunc("POST /otc/verify", h.VerifyOTC)

	mux.HandleFunc("POST /post/new", h.CreateNewPost)
	mux.HandleFunc("GET /post/{id}", h.GetPostById)
	mux.HandleFunc("GET /user/{id}/posts", h.GetPostsByUserId)

	// follow
	mux.HandleFunc("POST /follow/{user_id}", h.FollowUser)
	mux.HandleFunc("DELETE /follow/{user_id}", h.UnfollowUser)

	// likes
	mux.HandleFunc("POST /post/{id}/liked", h.AddPostLike)
	mux.HandleFunc("DELETE /post/{id}/liked", h.RemovePostLike)

	// notifications
	mux.HandleFunc("GET /notifications", h.GetAllNotificationByUserId)
	mux.HandleFunc("POST /notifications/markRead", h.MarkAllNotificationsAsRead)
	mux.HandleFunc("POST /notifications/{id}/markRead", h.MarkNotificationAsReadById)
	mux.HandleFunc("GET /notifications/hasUnread", h.HasUnreadNotifications)

	// comments
	mux.HandleFunc("POST /post/{post_id}/comment", h.AddCommentToPostById)
	mux.HandleFunc("POST /post/{post_id}/comment/{comment_id}/liked", h.AddCommentLike)
	mux.HandleFunc("DELETE /post/{post_id}/comment/{comment_id}/liked", h.RemoveCommentLike)

	mux.HandleFunc("GET /user/{id}", h.GetUserById)
	mux.HandleFunc("GET /posts/following", h.GetPostsByFollowing)
	mux.HandleFunc("GET /posts/all", h.GetAllPosts)

	// comments
	mux.HandleFunc("GET /post/{id}/comments", h.GetCommentsByPost)
}

func (h *Handler) writeJSON(w http.ResponseWriter, data interface{}, statusCode int) error {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(statusCode)
	return json.NewEncoder(w).Encode(data)
}

func (h *Handler) GetIntPathParam(r *http.Request, paramName string) (int, error) {
	paramString := r.PathValue(paramName)
	if paramString == "" {
		return 0, errors.New("missing url paramter")
	}
	param, err := strconv.Atoi(paramString)
	if err != nil {
		return 0, errors.New("cannot parse url parameter")
	}

	return param, nil
}
