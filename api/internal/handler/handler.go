package handler

import (
	"net/http"

	"splajompy.com/api/v2/internal/comment"
	"splajompy.com/api/v2/internal/db/queries"
	"splajompy.com/api/v2/internal/notification"
	"splajompy.com/api/v2/internal/post"
	"splajompy.com/api/v2/internal/user"

	"splajompy.com/api/v2/internal/service"
)

type Handler struct {
	queries             queries.Querier
	postService         *post.PostService
	commentHandler      *comment.Handler
	userHandler         *user.Handler
	notificationHandler *notification.Handler
	authService         *service.AuthService
	statsService        *service.StatsService
	wrappedService      *service.WrappedService
}

func NewHandler(queries queries.Querier,
	postService *post.PostService,
	commentHandler *comment.Handler,
	userHandler *user.Handler,
	notificationHandler *notification.Handler,
	authService *service.AuthService,
	statsService *service.StatsService,
	wrappedService *service.WrappedService) *Handler {
	return &Handler{
		queries:             queries,
		postService:         postService,
		commentHandler:      commentHandler,
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

	h.userHandler.RegisterRoutes(handleFuncWithAuth)
	h.notificationHandler.RegisterRoutes(handleFuncWithAuth)

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
