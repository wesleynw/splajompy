package middleware

import (
	"context"
	"net/http"

	"connectrpc.com/connect/v2"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/trace"
	"splajompy.com/api/v2/internal/utilities"
)

const (
	MinimumAppVersion = "v1.9.0"
	appUpgradeMessage = "You are using an unsupported version of Splajompy. Please visit the App Store to update."
)

func AppVersion(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ctx := appVersionContext(r.Context(), r.Header.Get("X-App-Version"))
		if !utilities.IsAppUpdatedToVersion(ctx, MinimumAppVersion) {
			w.Header().Set("X-Minimum-App-Version", MinimumAppVersion)
			utilities.HandleError(w, http.StatusUpgradeRequired, appUpgradeMessage)
			return
		}
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

func AppVersionInterceptor(next connect.ServerFunc) connect.ServerFunc {
	return func(ctx context.Context, spec connect.Spec, stream connect.ServerStream) error {
		info, _ := connect.CallInfoForServerContext(ctx)
		ctx = appVersionContext(ctx, info.RequestHeader().Get("X-App-Version"))
		if !utilities.IsAppUpdatedToVersion(ctx, MinimumAppVersion) {
			info.ResponseHeader().Set("X-Minimum-App-Version", MinimumAppVersion)
			return connect.NewError(connect.CodeFailedPrecondition, appUpgradeMessage)
		}
		return next(ctx, spec, stream)
	}
}

func appVersionContext(ctx context.Context, version string) context.Context {
	if version == "" {
		version = "unknown"
	} else if version[0] != 'v' {
		version = "v" + version
	}
	trace.SpanFromContext(ctx).SetAttributes(attribute.String("app.version", version))
	return context.WithValue(ctx, utilities.AppVersionKey, version)
}
