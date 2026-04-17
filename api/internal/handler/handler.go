package handler

import (
	"net/http"

	"splajompy.com/api/v2/internal/auth"
	"splajompy.com/api/v2/internal/comment"
	"splajompy.com/api/v2/internal/db/queries"
	"splajompy.com/api/v2/internal/notification"
	"splajompy.com/api/v2/internal/post"
	"splajompy.com/api/v2/internal/stats"
	"splajompy.com/api/v2/internal/user"
)

type Handler struct {
	queries             queries.Querier
	postService         *post.Service
	commentHandler      *comment.Handler
	userHandler         *user.Handler
	notificationHandler *notification.Handler
	authHandler         *auth.Handler
	statsHandler        *stats.Handler
}

func NewHandler(queries queries.Querier,
	postService *post.Service,
	commentHandler *comment.Handler,
	userHandler *user.Handler,
	notificationHandler *notification.Handler,
	authHandler *auth.Handler,
	statsHandler *stats.Handler) *Handler {
	return &Handler{
		queries:             queries,
		postService:         postService,
		commentHandler:      commentHandler,
		userHandler:         userHandler,
		notificationHandler: notificationHandler,
		authHandler:         authHandler,
		statsHandler:        statsHandler,
	}
}

func (h *Handler) RegisterRoutes(handleFunc func(pattern string, handlerFunc func(http.ResponseWriter, *http.Request)), authMiddleware func(http.Handler) http.Handler) {
	handleFuncWithAuth := func(pattern string, handlerFunc func(http.ResponseWriter, *http.Request)) {
		handleFunc(pattern, func(w http.ResponseWriter, r *http.Request) {
			authMiddleware(http.HandlerFunc(handlerFunc)).ServeHTTP(w, r)
		})
	}

	h.userHandler.RegisterRoutes(handleFuncWithAuth)
	h.notificationHandler.RegisterRoutes(handleFuncWithAuth)
	h.authHandler.RegisterPublicRoutes(handleFunc)
	h.authHandler.RegisterRoutes(handleFuncWithAuth)
	h.statsHandler.RegisterPublicRoutes(handleFunc)
	h.statsHandler.RegisterRoutes(handleFuncWithAuth)
}
