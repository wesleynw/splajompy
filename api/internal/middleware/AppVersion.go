package middleware

import (
	"context"
	"net/http"

	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/trace"
	"splajompy.com/api/v2/internal/utilities"
)

const MinimumAppVersion = "v1.8.1"

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

		ctx := context.WithValue(r.Context(), utilities.AppVersionKey, version)

		if !utilities.IsAppUpdatedToVersion(ctx, MinimumAppVersion) {
			utilities.HandleError(w, http.StatusUpgradeRequired, "You are using an unsupported version of Splajompy. Please visit the App Store to update.")
			return
		}

		next.ServeHTTP(w, r.WithContext(ctx))
	})
}
