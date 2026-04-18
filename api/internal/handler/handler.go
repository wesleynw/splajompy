package handler

import (
	"net/http"
)

type RouteRegistrar interface {
	RegisterRoutes(public, withAuth func(string, func(http.ResponseWriter, *http.Request)))
}

type Handler struct {
	registrars []RouteRegistrar
}

func NewHandler(registrars ...RouteRegistrar) *Handler {
	return &Handler{registrars: registrars}
}

func (h *Handler) RegisterRoutes(handleFunc func(string, func(http.ResponseWriter, *http.Request)), authMiddleware func(http.Handler) http.Handler) {
	withAuth := func(pattern string, handlerFunc func(http.ResponseWriter, *http.Request)) {
		handleFunc(pattern, func(w http.ResponseWriter, r *http.Request) {
			authMiddleware(http.HandlerFunc(handlerFunc)).ServeHTTP(w, r)
		})
	}

	for _, r := range h.registrars {
		r.RegisterRoutes(handleFunc, withAuth)
	}
}
