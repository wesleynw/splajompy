package middleware

import (
	"context"
	"net/http"

	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/trace"
	"splajompy.com/api/v2/internal/utilities"
)

const (
	MinimumAppVersion = "v1.9.0"
	AppUpgradeMessage = "You are using an unsupported version of Splajompy. Please visit the App Store to update."
)

func AppVersion(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ctx := WithAppVersion(r.Context(), r.Header.Get("X-App-Version"))
		if !utilities.IsAppUpdatedToVersion(ctx, MinimumAppVersion) {
			w.Header().Set("X-Minimum-App-Version", MinimumAppVersion)
			utilities.HandleError(w, http.StatusUpgradeRequired, AppUpgradeMessage)
			return
		}
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

func WithAppVersion(ctx context.Context, version string) context.Context {
	if version == "" {
		version = "unknown"
	} else if version[0] != 'v' {
		version = "v" + version
	}
	trace.SpanFromContext(ctx).SetAttributes(attribute.String("app.version", version))
	return context.WithValue(ctx, utilities.AppVersionKey, version)
}
