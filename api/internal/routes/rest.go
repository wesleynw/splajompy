package routes

import (
	"net/http"

	"splajompy.com/api/v2/internal/db/queries"
	"splajompy.com/api/v2/internal/middleware"
)

type RESTRegistrar interface {
	RegisterRESTRoutes(public, withAuth func(string, func(http.ResponseWriter, *http.Request)))
}

func RegisterREST(mux *http.ServeMux, q *queries.Queries, registrars ...RESTRegistrar) {
	public := func(pattern string, handler func(http.ResponseWriter, *http.Request)) {
		mux.Handle(pattern, middleware.AppVersion(http.HandlerFunc(handler)))
	}
	auth := middleware.AuthMiddleware(q)
	withAuth := func(pattern string, handler func(http.ResponseWriter, *http.Request)) {
		mux.Handle(pattern, middleware.AppVersion(auth(http.HandlerFunc(handler))))
	}
	for _, registrar := range registrars {
		registrar.RegisterRESTRoutes(public, withAuth)
	}
}
