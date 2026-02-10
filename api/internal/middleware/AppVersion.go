package middleware

import (
	"context"
	"net/http"

	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/trace"
	"splajompy.com/api/v2/internal/utilities"
)

const AppVersionKey utilities.ContextKey = "app_version"

func AppVersion(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		version := r.Header.Get("X-App-Version")
		if version == "" {
			version = "unknown"
		} else if version[0] != 'v' {
			version = "v" + version
		}

		span := trace.SpanFromContext(r.Context())
		span.SetAttributes(attribute.String("app.version", version))

		ctx := context.WithValue(r.Context(), AppVersionKey, version)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}
