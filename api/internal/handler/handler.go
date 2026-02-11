package handler

import (
	"errors"
	"net/http"
	"strconv"

	"splajompy.com/api/v2/internal/db/queries"
	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/utilities"

	"splajompy.com/api/v2/internal/service"
)

type Handler struct {
	queries             queries.Querier
	postService         *service.PostService
	commentService      *service.CommentService
	userService         *service.UserService
	notificationService *service.NotificationService
	authService         *service.AuthService
	statsService        *service.StatsService
	wrappedService      *service.WrappedService
}

func NewHandler(queries queries.Querier,
	postService *service.PostService,
	commentService *service.CommentService,
	userService *service.UserService,
	notificationService *service.NotificationService,
	authService *service.AuthService,
	statsService *service.StatsService,
	wrappedService *service.WrappedService) *Handler {
	return &Handler{
		queries:             queries,
		postService:         postService,
		commentService:      commentService,
		userService:         userService,
		notificationService: notificationService,
		authService:         authService,
		statsService:        statsService,
		wrappedService:      wrappedService,
	}
}

func (h *Handler) RegisterRoutes(handleFunc func(pattern string, handlerFunc func(http.ResponseWriter, *http.Request)), authMiddleware func(http.Handler) http.Handler) {
	handleFuncWithAuth := func(pattern string, handlerFunc func(http.ResponseWriter, *http.Request)) {
		handleFunc(pattern, func(w http.ResponseWriter, r *http.Request) {
			authMiddleware(http.HandlerFunc(handlerFunc)).ServeHTTP(w, r)
		})
	}

	// auth
	handleFuncWithAuth("POST /account/delete", h.DeleteAccount)

	// posts
	handleFuncWithAuth("GET /post/presignedUrl", h.GetPresignedUrl)
	handleFuncWithAuth("POST /v2/post/new", h.CreateNewPostV2)
	handleFuncWithAuth("GET /post/{id}", h.GetPostById)
	// handleFuncWithAuth("GET /user/{id}/posts", h.GetPostsByUserId)
	handleFuncWithAuth("DELETE /post/{id}", h.DeletePostById)
	handleFuncWithAuth("POST /post/{id}/report", h.ReportPost)

	// polls
	handleFuncWithAuth("POST /post/{post_id}/vote/{option_index}", h.VoteOnPost)

	// follow
	handleFuncWithAuth("POST /follow/{user_id}", h.FollowUser)
	handleFuncWithAuth("DELETE /follow/{user_id}", h.UnfollowUser)

	handleFuncWithAuth("POST /user/profile", h.UpdateProfile)

	// likes
	handleFuncWithAuth("POST /post/{id}/liked", h.AddPostLike)
	handleFuncWithAuth("DELETE /post/{id}/liked", h.RemovePostLike)

	// pinning
	handleFuncWithAuth("POST /posts/{id}/pin", h.PinPost)
	handleFuncWithAuth("DELETE /posts/pin", h.UnpinPost)

	// notifications
	handleFuncWithAuth("GET /notifications", h.GetAllNotificationByUserId)
	handleFuncWithAuth("GET /notifications/unread", h.GetUnreadNotificationsByUserId)
	handleFuncWithAuth("POST /notifications/markRead", h.MarkAllNotificationsAsRead)
	handleFuncWithAuth("POST /notifications/{id}/markRead", h.MarkNotificationAsReadById)
	handleFuncWithAuth("GET /notifications/hasUnread", h.HasUnreadNotifications)
	handleFuncWithAuth("GET /notifications/unreadCount", h.GetUnreadNotificationCount)
	handleFuncWithAuth("GET /notifications/read/time", h.GetReadNotificationsByUserIdWithTimeOffset)
	handleFuncWithAuth("GET /notifications/unread/time", h.GetUnreadNotificationsByUserIdWithTimeOffset)

	// comments
	handleFuncWithAuth("POST /post/{post_id}/comment", h.AddCommentToPostById)
	handleFuncWithAuth("POST /post/{post_id}/comment/{comment_id}/liked", h.AddCommentLike)
	handleFuncWithAuth("DELETE /post/{post_id}/comment/{comment_id}/liked", h.RemoveCommentLike)
	handleFuncWithAuth("DELETE /comment/{comment_id}", h.DeleteComment)
	handleFuncWithAuth("GET /post/{id}/comments", h.GetCommentsByPost)

	// blocking
	handleFuncWithAuth("POST /user/{user_id}/block", h.BlockUser)
	handleFuncWithAuth("DELETE /user/{user_id}/block", h.UnblockUser)

	// muting
	handleFuncWithAuth("POST /user/{user_id}/mute", h.MuteUser)
	handleFuncWithAuth("DELETE /user/{user_id}/mute", h.UnmuteUser)

	// users
	handleFuncWithAuth("GET /user/{id}", h.GetUserById)
	handleFuncWithAuth("GET /user/{id}/followers", h.GetFollowersByUserId_old)
	handleFuncWithAuth("GET /user/{id}/following", h.GetFollowingByUserId_old)
	handleFuncWithAuth("GET /v2/user/{id}/following", h.GetFollowingByUserId)
	handleFuncWithAuth("GET /user/{id}/mutuals", h.GetMutualsByUserId_old)
	handleFuncWithAuth("GET /v2/user/{id}/mutuals", h.GetMutualsByUserId)
	handleFuncWithAuth("GET /users/search", h.SearchUsers)

	handleFuncWithAuth("POST /user/{id}/friend", h.AddUserToCloseFriendsList)
	handleFuncWithAuth("DELETE /user/{id}/friend", h.RemoveUserFromCloseFriendsList)
	handleFuncWithAuth("GET /user/friends", h.ListUserCloseFriends)

	// post routes with time-based offset
	handleFuncWithAuth("GET /v2/posts/following", h.GetPostsByFollowingWithTimeOffset)
	handleFuncWithAuth("GET /v2/posts/all", h.GetAllPostsWithTimeOffset)
	handleFuncWithAuth("GET /v2/posts/mutual", h.GetMutualFeedWithTimeOffset)
	handleFuncWithAuth("GET /v2/user/{id}/posts", h.GetPostsByUserIdWithTimeOffset)

	// misc
	handleFuncWithAuth("POST /request-feature", h.RequestFeature)
	handleFuncWithAuth("GET /stats", h.GetAppStats)

	// wrapped
	handleFuncWithAuth("POST /precomuputeWrapped", h.WrappedPrecomputation)
	handleFuncWithAuth("GET /wrapped", h.GetWrappedActivityData)
	handleFuncWithAuth("GET /wrapped/eligibility", h.GetIsUserEligibleForWrapped)
}

func (h *Handler) RegisterPublicRoutes(handleFunc func(pattern string, handlerFunc func(http.ResponseWriter, *http.Request))) {
	handleFunc("POST /register", h.Register)
	handleFunc("POST /login", h.Login)
	handleFunc("POST /otc/generate", h.GenerateOTC)
	handleFunc("POST /otc/verify", h.VerifyOTC)
	handleFunc("GET /health", h.GetAppHealth)
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

func (h *Handler) getAuthenticatedUser(r *http.Request) *models.PublicUser {
	return new(r.Context().Value(utilities.UserContextKey).(models.PublicUser))
}
