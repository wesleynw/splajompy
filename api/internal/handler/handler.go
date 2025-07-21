package handler

import (
	"errors"
	"net/http"
	"splajompy.com/api/v2/internal/db/queries"
	"strconv"

	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
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
	// handleFunc is a replacement for mux.HandleFunc
	// which enriches the handler's HTTP instrumentation with the pattern as the http.route.
	handleFunc := func(pattern string, handlerFunc func(http.ResponseWriter, *http.Request)) {
		// Configure the "http.route" for the HTTP instrumentation.
		handler := otelhttp.WithRouteTag(pattern, http.HandlerFunc(handlerFunc))
		mux.Handle(pattern, handler)
	}

	// auth
	handleFunc("POST /register", h.Register)
	handleFunc("POST /login", h.Login)
	handleFunc("POST /otc/generate", h.GenerateOTC)
	handleFunc("POST /otc/verify", h.VerifyOTC)
	handleFunc("POST /account/delete", h.DeleteAccount)

	// posts
	handleFunc("GET /post/presignedUrl", h.GetPresignedUrl)
	handleFunc("POST /post/new", h.CreateNewPost)
	handleFunc("POST /v2/post/new", h.CreateNewPostV2)
	handleFunc("GET /post/{id}", h.GetPostById)
	handleFunc("GET /user/{id}/posts", h.GetPostsByUserId)
	handleFunc("DELETE /post/{id}", h.DeletePostById)
	handleFunc("POST /post/{id}/report", h.ReportPost)

	// polls
	handleFunc("POST /post/{post_id}/vote/{option_index}", h.VoteOnPost)

	// follow
	handleFunc("POST /follow/{user_id}", h.FollowUser)
	handleFunc("DELETE /follow/{user_id}", h.UnfollowUser)

	handleFunc("POST /user/profile", h.UpdateProfile)

	// likes
	handleFunc("POST /post/{id}/liked", h.AddPostLike)
	handleFunc("DELETE /post/{id}/liked", h.RemovePostLike)

	// notifications
	handleFunc("GET /notifications", h.GetAllNotificationByUserId)
	handleFunc("GET /notifications/unread", h.GetUnreadNotificationsByUserId)
	handleFunc("POST /notifications/markRead", h.MarkAllNotificationsAsRead)
	handleFunc("POST /notifications/{id}/markRead", h.MarkNotificationAsReadById)
	handleFunc("GET /notifications/hasUnread", h.HasUnreadNotifications)
	handleFunc("GET /notifications/unreadCount", h.GetUnreadNotificationCount)
	handleFunc("GET /notifications/read/time", h.GetReadNotificationsByUserIdWithTimeOffset)
	handleFunc("GET /notifications/unread/time", h.GetUnreadNotificationsByUserIdWithTimeOffset)

	// comments
	handleFunc("POST /post/{post_id}/comment", h.AddCommentToPostById)
	handleFunc("POST /post/{post_id}/comment/{comment_id}/liked", h.AddCommentLike)
	handleFunc("DELETE /post/{post_id}/comment/{comment_id}/liked", h.RemoveCommentLike)

	// blocking
	handleFunc("POST /user/{user_id}/block", h.BlockUser)
	handleFunc("DELETE /user/{user_id}/block", h.UnblockUser)

	handleFunc("GET /user/{id}", h.GetUserById)
	handleFunc("GET /posts/following", h.GetPostsByFollowing)
	handleFunc("GET /posts/all", h.GetAllPosts)
	handleFunc("GET /posts/mutual", h.GetMutualFeed)

	handleFunc("GET /users/search", h.SearchUsers)

	// comments
	handleFunc("GET /post/{id}/comments", h.GetCommentsByPost)
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
