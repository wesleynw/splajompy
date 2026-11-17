package routes

import (
	"net/http"
	"time"

	"connectrpc.com/connect/v2"
	"connectrpc.com/connect/v2/connecthttp"
	"connectrpc.com/validate"
	"splajompy.com/api/v2/internal/db/queries"
	"splajompy.com/api/v2/internal/interceptor"
	"splajompy.com/api/v2/internal/middleware"
)

// rpcMaxReadBytes limits each decompressed request message to 4 MiB.
const rpcMaxReadBytes = 4 * 1024 * 1024

type RESTRegistrar interface {
	RegisterRESTRoutes(public, withAuth func(string, func(http.ResponseWriter, *http.Request)))
}

type RPCRegistrar interface {
	RegisterRPCRoutes(public, withAuth *connect.Server)
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

func RegisterRPC(mux *http.ServeMux, q *queries.Queries, writeTimeout time.Duration, registrars ...RPCRegistrar) {
	public := connect.NewServer(interceptor.AppVersion, validate.NewServerInterceptor())
	withAuth := connect.NewServer(interceptor.AppVersion, interceptor.Auth(q), validate.NewServerInterceptor())

	for _, registrar := range registrars {
		registrar.RegisterRPCRoutes(public, withAuth)
	}

	for _, server := range []*connect.Server{public, withAuth} {
		streaming := make(map[string]bool)
		for spec := range server.Specs() {
			streaming[spec.Procedure] = spec.StreamType != connect.StreamTypeUnary
		}
		connecthttp.Mount(rpcMux{
			ServeMux:     mux,
			streaming:    streaming,
			writeTimeout: writeTimeout,
		}, server, connecthttp.WithReadMaxBytes(rpcMaxReadBytes))
	}
}

type rpcMux struct {
	*http.ServeMux
	streaming    map[string]bool
	writeTimeout time.Duration
}

func (mux rpcMux) Handle(pattern string, handler http.Handler) {
	if mux.streaming[pattern] {
		handler = middleware.StreamWriteTimeout(handler, mux.writeTimeout)
	}
	mux.ServeMux.Handle(pattern, handler)
}
