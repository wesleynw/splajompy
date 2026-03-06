package middleware

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"strings"
	"time"

	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgtype"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/codes"
	"golang.org/x/mod/semver"
	"splajompy.com/api/v2/internal/db"
	"splajompy.com/api/v2/internal/db/queries"
	"splajompy.com/api/v2/internal/utilities"
)

var tracer = otel.Tracer("splajompy.com/api/v2/internal/middleware")

func AuthMiddleware(q *queries.Queries) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			ctx := r.Context()

			ctx, span := tracer.Start(ctx, "AuthMiddleware")
			defer span.End()

			header := r.Header.Get("Authorization")

			if header == "" {
				slog.WarnContext(ctx, "auth: missing authorization header")
				http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
				return
			}

			parts := strings.Split(header, "Bearer ")
			if len(parts) != 2 {
				slog.WarnContext(ctx, "auth: malformed authorization header")
				http.Error(w, "Missing authorization header", http.StatusBadRequest)
				return
			}

			token := strings.ReplaceAll(strings.TrimSpace(parts[1]), `\/`, `/`)

			session, err := q.GetSessionById(ctx, token)
			if err != nil {
				span.SetStatus(codes.Error, "unable to grab user session")
				span.RecordError(err)
			}
			// want to be careful here: if it's a server error, don't want to be logging
			// people out automatically
			var connectError *pgconn.ConnectError
			if errors.As(err, &connectError) {
				slog.ErrorContext(ctx, "auth: db connection error looking up session", "error", err)
				http.Error(w, "something went wrong", http.StatusInternalServerError)
				return
			} else if err != nil {
				slog.WarnContext(ctx, "auth: session not found", "error", err)
				http.Error(w, "no session found", http.StatusUnauthorized)
				return
			}

			if time.Now().Unix() >= session.ExpiresAt.Time.Unix() {
				slog.InfoContext(ctx, "auth: session expired", "session_id", session.ID, "expired_at", session.ExpiresAt.Time)
				err = q.DeleteSession(ctx, session.ID)
				if err != nil {
					slog.ErrorContext(ctx, "auth: failed to delete expired session", "session_id", session.ID, "error", err)
					http.Error(w, "failed to delete expired session", http.StatusInternalServerError)
					return
				}
				http.Error(w, "session expired", http.StatusUnauthorized)
				return
			}

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
					slog.WarnContext(ctx, "auth: failed to extend session", "session_id", session.ID, "error", err)
				}
			}

			dbUser, err := q.GetUserById(ctx, session.UserID)
			if err != nil {
				slog.ErrorContext(ctx, "auth: failed to fetch user", "user_id", session.UserID, "error", err)
				utilities.HandleError(w, http.StatusBadRequest, err.Error())
				return
			}

			// log latest app version in profile
			versionAny := ctx.Value(AppVersionKey)
			version, ok := versionAny.(string)
			userDisplayProperties := dbUser.UserDisplayProperties
			if userDisplayProperties == nil {
				userDisplayProperties = &db.UserDisplayProperties{}
			}
			if ok && (userDisplayProperties.LatestAppVersion == nil || semver.Compare(version, *userDisplayProperties.LatestAppVersion) > 0) {
				userDisplayProperties.LatestAppVersion = &version
			}

			now := time.Now().UTC()
			if userDisplayProperties.LastLoginDate == nil ||
				userDisplayProperties.LastLoginDate.UTC().Truncate(24*time.Hour).
					Before(now.Truncate(24*time.Hour)) {

				userDisplayProperties.LastLoginDate = &now
			}

			err = q.UpdateUserDisplayProperties(ctx, queries.UpdateUserDisplayPropertiesParams{
				UserID:                dbUser.UserID,
				UserDisplayProperties: userDisplayProperties,
			})

			if err != nil {
				span.SetStatus(codes.Error, "unable to record latest app version")
				span.RecordError(err)
			}

			publicUser := utilities.MapUserToPublicUser(dbUser)

			span.SetAttributes(attribute.Int("user.id", session.UserID))

			ctx = context.WithValue(ctx, utilities.UserContextKey, publicUser)
			r = r.WithContext(ctx)

			next.ServeHTTP(w, r)
		})
	}
}
