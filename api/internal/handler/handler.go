package handler

import (
	"net/http"

	"connectrpc.com/connect/v2"
	"connectrpc.com/connect/v2/connecthttp"
	"connectrpc.com/validate"
	"splajompy.com/api/v2/internal/db/queries"
	"splajompy.com/api/v2/internal/interceptor"
	"splajompy.com/api/v2/internal/middleware"
)

type RESTRegistrar interface {
	RegisterRESTRoutes(public, withAuth func(string, func(http.ResponseWriter, *http.Request)))
}

// ConnectRegistrar registers each service on either public or withAuth.
type ConnectRegistrar interface {
	RegisterConnectRoutes(public, withAuth *connect.Server)
}

type Handler struct {
	restRegistrars    []RESTRegistrar
	connectRegistrars []ConnectRegistrar
}

func NewHandler(restRegistrars []RESTRegistrar, connectRegistrars []ConnectRegistrar) *Handler {
	return &Handler{restRegistrars: restRegistrars, connectRegistrars: connectRegistrars}
}

func (h *Handler) RegisterRESTRoutes(mux *http.ServeMux, q *queries.Queries) {
	public := func(pattern string, handler func(http.ResponseWriter, *http.Request)) {
		mux.Handle(pattern, middleware.AppVersion(http.HandlerFunc(handler)))
	}
	auth := middleware.AuthMiddleware(q)
	withAuth := func(pattern string, handler func(http.ResponseWriter, *http.Request)) {
		mux.Handle(pattern, middleware.AppVersion(auth(http.HandlerFunc(handler))))
	}
	for _, r := range h.restRegistrars {
		r.RegisterRESTRoutes(public, withAuth)
	}
}

func (h *Handler) RegisterConnectRoutes(mux *http.ServeMux, q *queries.Queries) {
	public := connect.NewServer(interceptor.AppVersion, validate.NewServerInterceptor())
	withAuth := connect.NewServer(interceptor.AppVersion, interceptor.Auth(q), validate.NewServerInterceptor())
	for _, r := range h.connectRegistrars {
		r.RegisterConnectRoutes(public, withAuth)
	}
	connecthttp.Mount(mux, public)
	connecthttp.Mount(mux, withAuth)
}
