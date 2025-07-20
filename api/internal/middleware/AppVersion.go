package middleware

import (
	"context"
	"net/http"
)

const AppVersionKey = "app_version"

func AppVersion(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		version := r.Header.Get("X-App-Version")
		if version == "" {
			version = "unknown"
		}

		ctx := context.WithValue(r.Context(), AppVersionKey, version)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}
