package server

import (
	"net/http"
	"time"

	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	semconv "go.opentelemetry.io/otel/semconv/v1.37.0"
	"go.opentelemetry.io/otel/trace"
	"splajompy.com/api/v2/internal/middleware"
)

const (
	httpAddress       = ":8080"
	readHeaderTimeout = 5 * time.Second
	readTimeout       = 30 * time.Second
	writeTimeout      = time.Minute
	idleTimeout       = 2 * time.Minute
)

func NewServer() (*http.Server, *http.ServeMux) {
	mux := http.NewServeMux()

	routeTelemetryHandler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		mux.ServeHTTP(w, r)
		span := trace.SpanFromContext(r.Context())
		if r.Pattern != "" {
			span.SetName(r.Pattern)
			span.SetAttributes(semconv.HTTPRoute(r.Pattern))
			if labeler, ok := otelhttp.LabelerFromContext(r.Context()); ok {
				labeler.Add(semconv.HTTPRoute(r.Pattern))
			}
		} else {
			span.SetName(r.Method + " " + r.URL.Path)
		}
	})

	loggingHandler := middleware.Logger(routeTelemetryHandler)

	httpHandler := otelhttp.NewHandler(loggingHandler, "/")
	httpServer := &http.Server{
		Addr:              httpAddress,
		Handler:           httpHandler,
		Protocols:         new(http.Protocols),
		ReadHeaderTimeout: readHeaderTimeout,
		ReadTimeout:       readTimeout,
		WriteTimeout:      writeTimeout,
		IdleTimeout:       idleTimeout,
	}
	httpServer.Protocols.SetHTTP1(true)
	httpServer.Protocols.SetUnencryptedHTTP2(true)

	return httpServer, mux
}
