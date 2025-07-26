package middleware

import (
	"context"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/trace"
	"net/http"
	"splajompy.com/api/v2/internal/db/queries"
	"splajompy.com/api/v2/internal/utilities"
	"strings"
	"time"
)

func AuthMiddleware(q *queries.Queries) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			ctx := r.Context()
			header := r.Header.Get("Authorization")

			if header == "" {
				http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
				return
			}

			parts := strings.Split(header, "Bearer ")
			if len(parts) != 2 {
				http.Error(w, "Missing authorization header", http.StatusBadRequest)
				return
			}

			token := strings.ReplaceAll(strings.TrimSpace(parts[1]), `\/`, `/`)

			session, err := q.GetSessionById(ctx, token)
			if err != nil {
				http.Error(w, "no session found", http.StatusUnauthorized)
				return
			}

			if time.Now().Unix() >= session.ExpiresAt.Time.Unix() {
				err = q.DeleteSession(ctx, session.ID)
				if err != nil {
					http.Error(w, "failed to delete expired session", http.StatusInternalServerError)
					return
				}
				http.Error(w, "session expired", http.StatusUnauthorized)
				return
			}

			dbUser, err := q.GetUserById(ctx, session.UserID)
			if err != nil {
				http.Error(w, "user not found", http.StatusUnauthorized)
				return
			}

			publicUser := utilities.MapUserToPublicUser(dbUser)

			span := trace.SpanFromContext(ctx)
			span.SetAttributes(attribute.Int("user.id", int(session.UserID)))

			ctx = context.WithValue(ctx, utilities.UserContextKey, publicUser)
			r = r.WithContext(ctx)

			next.ServeHTTP(w, r)
		})
	}
}
