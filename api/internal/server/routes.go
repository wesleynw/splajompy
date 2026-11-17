package server

import (
	"net/http"
	"time"

	"connectrpc.com/connect/v2"
	"connectrpc.com/connect/v2/connecthttp"
	"connectrpc.com/validate"
	"splajompy.com/api/v2/gen/splajompy/v1/splajompyv1connect"
	"splajompy.com/api/v2/internal/db/queries"
	"splajompy.com/api/v2/internal/interceptor"
	"splajompy.com/api/v2/internal/middleware"
)

// rpcMaxReadBytes limits each decompressed request message to 4 MiB.
const rpcMaxReadBytes = 4 * 1024 * 1024

const notificationStreamWriteTimeout = time.Minute

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

func RegisterRPC(mux *http.ServeMux, q *queries.Queries, registrars ...RPCRegistrar) {
	public := connect.NewServer(interceptor.AppVersion, validate.NewServerInterceptor())
	withAuth := connect.NewServer(interceptor.AppVersion, interceptor.Auth(q), validate.NewServerInterceptor())

	for _, registrar := range registrars {
		registrar.RegisterRPCRoutes(public, withAuth)
	}

	rpcMux := http.NewServeMux()
	for _, server := range []*connect.Server{public, withAuth} {
		connecthttp.Mount(rpcMux, server, connecthttp.WithReadMaxBytes(rpcMaxReadBytes))
	}
	mux.Handle(splajompyv1connect.NotificationServiceWatchUnreadNotificationCountProcedure,
		middleware.StreamWriteTimeout(rpcMux, notificationStreamWriteTimeout))
	mux.Handle("/", rpcMux)
}
