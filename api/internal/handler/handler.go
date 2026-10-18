package handler

import (
	"net/http"

	"connectrpc.com/connect/v2"
	"connectrpc.com/connect/v2/connecthttp"
	"splajompy.com/api/v2/internal/db/queries"
	"splajompy.com/api/v2/internal/middleware"
)

type RESTRegistrar interface {
	RegisterRESTRoutes(public, withAuth func(string, func(http.ResponseWriter, *http.Request)))
}

// ConnectRegistrar registers services whose procedures require authentication by default.
// Only exact paths returned in anonymousProcedures allow requests without authentication.
type ConnectRegistrar interface {
	RegisterConnectRoutes(*connect.Server) (anonymousProcedures []string)
}

type Handler struct {
	restRegistrars    []RESTRegistrar
	connectRegistrars []ConnectRegistrar
}

func NewHandler(restRegistrars []RESTRegistrar, connectRegistrars []ConnectRegistrar) *Handler {
	return &Handler{restRegistrars: restRegistrars, connectRegistrars: connectRegistrars}
}

func (h *Handler) RegisterRESTRoutes(mux *http.ServeMux, q *queries.Queries) {
	errorWriter := middleware.ErrorWriter{}
	public := routeMux{mux: mux, errorWriter: errorWriter}
	withAuth := routeMux{mux: mux, auth: middleware.AuthMiddleware(q, errorWriter), errorWriter: errorWriter}
	for _, r := range h.restRegistrars {
		r.RegisterRESTRoutes(public.HandleFunc, withAuth.HandleFunc)
	}
}

func (h *Handler) RegisterConnectRoutes(mux *http.ServeMux, q *queries.Queries) {
	errorWriter := middleware.NewConnectErrorWriter()
	public := routeMux{mux: mux, errorWriter: errorWriter}
	withAuth := routeMux{mux: mux, auth: middleware.AuthMiddleware(q, errorWriter), errorWriter: errorWriter}
	server := connect.NewServer()
	routes := connectMux{
		public:              public,
		withAuth:            withAuth,
		anonymousProcedures: make(map[string]bool),
	}
	for _, r := range h.connectRegistrars {
		for _, procedure := range r.RegisterConnectRoutes(server) {
			routes.anonymousProcedures[procedure] = true
		}
	}
	connecthttp.Mount(routes, server)
}

type routeMux struct {
	mux         *http.ServeMux
	auth        func(http.Handler) http.Handler
	errorWriter middleware.ErrorWriter
}

func (r routeMux) Handle(pattern string, next http.Handler) {
	if r.auth != nil {
		next = r.auth(next)
	}
	r.mux.Handle(pattern, middleware.AppVersion(next, r.errorWriter))
}

func (r routeMux) HandleFunc(pattern string, handler func(http.ResponseWriter, *http.Request)) {
	r.Handle(pattern, http.HandlerFunc(handler))
}

type connectMux struct {
	public              routeMux
	withAuth            routeMux
	anonymousProcedures map[string]bool
}

func (r connectMux) Handle(pattern string, next http.Handler) {
	routes := r.withAuth
	if r.anonymousProcedures[pattern] {
		routes = r.public
	}
	routes.Handle(pattern, next)
}
