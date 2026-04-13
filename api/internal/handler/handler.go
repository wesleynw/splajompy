package handler

import (
	"net/http"

	"splajompy.com/api/v2/internal/db/queries"
	"splajompy.com/api/v2/internal/notification"
	"splajompy.com/api/v2/internal/user"

	"splajompy.com/api/v2/internal/service"
)

type Handler struct {
	queries             queries.Querier
	postService         *service.PostService
	commentService      *service.CommentService
	userHandler         *user.Handler
	notificationHandler *notification.Handler
	authService         *service.AuthService
	statsService        *service.StatsService
	wrappedService      *service.WrappedService
}

func NewHandler(queries queries.Querier,
	postService *service.PostService,
	commentService *service.CommentService,
	userHandler *user.Handler,
	notificationHandler *notification.Handler,
	authService *service.AuthService,
	statsService *service.StatsService,
	wrappedService *service.WrappedService) *Handler {
	return &Handler{
		queries:             queries,
		postService:         postService,
		commentService:      commentService,
		userHandler:         userHandler,
		notificationHandler: notificationHandler,
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

	// likes
	handleFuncWithAuth("POST /post/{id}/liked", h.AddPostLike)
	handleFuncWithAuth("DELETE /post/{id}/liked", h.RemovePostLike)

	// pinning
	handleFuncWithAuth("POST /posts/{id}/pin", h.PinPost)
	handleFuncWithAuth("DELETE /posts/pin", h.UnpinPost)

	h.userHandler.RegisterRoutes(handleFuncWithAuth)
	h.notificationHandler.RegisterRoutes(handleFuncWithAuth)

	// comments
	handleFuncWithAuth("POST /post/{post_id}/comment", h.AddCommentToPostById)
	handleFuncWithAuth("POST /post/{post_id}/comment/{comment_id}/liked", h.AddCommentLike)
	handleFuncWithAuth("DELETE /post/{post_id}/comment/{comment_id}/liked", h.RemoveCommentLike)
	handleFuncWithAuth("DELETE /comment/{comment_id}", h.DeleteComment)
	handleFuncWithAuth("GET /post/{id}/comments", h.GetCommentsByPost)

	// post routes with time-based offset
	handleFuncWithAuth("GET /v2/posts/following", h.GetPostsByFollowingWithTimeOffset)
	handleFuncWithAuth("GET /v2/posts/all", h.GetAllPostsWithTimeOffset)
	handleFuncWithAuth("GET /v2/posts/mutual", h.GetMutualFeedWithTimeOffset)
	handleFuncWithAuth("GET /v2/user/{id}/posts", h.GetPostsByUserIdWithTimeOffset)
	// misc
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
	handleFunc("GET /version-availability", h.GetVersionAvailability)
}
