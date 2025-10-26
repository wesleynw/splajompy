package middleware

import (
	"context"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/jackc/pgx/v5/pgtype"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/trace"
	"splajompy.com/api/v2/internal/db/queries"
	"splajompy.com/api/v2/internal/utilities"
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

			// TODO: refresh tokens
			//if time.Now().Unix() >= session.ExpiresAt.Time.Unix() {
			//	err = q.DeleteSession(ctx, session.ID)
			//	if err != nil {
			//		http.Error(w, "failed to delete expired session", http.StatusInternalServerError)
			//		return
			//	}
			//	http.Error(w, "session expired", http.StatusUnauthorized)
			//	return
			//}

			// extend session if it's getting old (expires within 30 days)
			thirtyDaysFromNow := time.Now().Add(time.Hour * 24 * 30)
			if session.ExpiresAt.Time.Before(thirtyDaysFromNow) {
				newExpiry := time.Now().Add(time.Hour * 24 * 90)
				err = q.UpdateSessionExpiry(ctx, queries.UpdateSessionExpiryParams{
					ID: session.ID,
					ExpiresAt: pgtype.Timestamp{
						Time:  newExpiry,
						Valid: true,
					},
				})
				if err != nil {
					fmt.Printf("Failed to extend session: %v\n", err)
				}
			}

			dbUser, err := q.GetUserById(ctx, session.UserID)
			if err != nil {
				http.Error(w, "user not found", http.StatusUnauthorized)
				return
			}

			publicUser := utilities.MapUserToPublicUser(dbUser)

			span := trace.SpanFromContext(ctx)
			span.SetAttributes(attribute.Int("user.id", session.UserID))

			ctx = context.WithValue(ctx, utilities.UserContextKey, publicUser)
			r = r.WithContext(ctx)

			next.ServeHTTP(w, r)
		})
	}
}
