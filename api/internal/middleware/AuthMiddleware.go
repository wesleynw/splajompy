package middleware

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"strings"
	"time"

	"connectrpc.com/connect/v2"
	"github.com/jackc/pgx/v5"
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
			ctx, err := authenticate(r.Context(), q, r.Header.Get("Authorization"))
			if err != nil {
				utilities.HandleError(w, err.status, err.Error())
				return
			}
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

func AuthInterceptor(q *queries.Queries) connect.ServerInterceptor {
	return func(next connect.ServerFunc) connect.ServerFunc {
		return func(ctx context.Context, spec connect.Spec, stream connect.ServerStream) error {
			info, _ := connect.CallInfoForServerContext(ctx)
			ctx, err := authenticate(ctx, q, info.RequestHeader().Get("Authorization"))
			if err != nil {
				code, message := connect.CodeInternal, http.StatusText(http.StatusInternalServerError)
				switch err.status {
				case http.StatusBadRequest:
					code, message = connect.CodeInvalidArgument, err.Error()
				case http.StatusUnauthorized:
					code, message = connect.CodeUnauthenticated, err.Error()
				}
				return connect.NewError(code, message)
			}
			return next(ctx, spec, stream)
		}
	}
}

type authError struct {
	status  int
	message string
}

func (e *authError) Error() string {
	return e.message
}

func authenticate(ctx context.Context, q *queries.Queries, header string) (context.Context, *authError) {
	ctx, span := tracer.Start(ctx, "authenticate")
	defer span.End()

	if header == "" {
		slog.WarnContext(ctx, "auth: missing authorization header")
		return nil, &authError{status: http.StatusUnauthorized, message: http.StatusText(http.StatusUnauthorized)}
	}

	scheme, token, ok := strings.Cut(header, " ")
	token = strings.TrimSpace(token)
	if !ok || !strings.EqualFold(scheme, "Bearer") || token == "" {
		slog.WarnContext(ctx, "auth: malformed authorization header")
		return nil, &authError{status: http.StatusBadRequest, message: "Invalid authorization header"}
	}

	token = strings.ReplaceAll(token, `\/`, `/`)

	session, err := q.GetSessionById(ctx, token)
	if err != nil {
		span.SetStatus(codes.Error, "unable to grab user session")
		span.RecordError(err)
	}
	// want to be careful here: if it's a server error, don't want to be logging
	// people out automatically
	if errors.Is(err, pgx.ErrNoRows) {
		slog.WarnContext(ctx, "auth: session not found", "error", err)
		return nil, &authError{status: http.StatusUnauthorized, message: "no session found"}
	} else if err != nil {
		slog.ErrorContext(ctx, "auth: failed to fetch session", "error", err)
		return nil, &authError{status: http.StatusInternalServerError, message: "something went wrong"}
	}

	if time.Now().Unix() >= session.ExpiresAt.Unix() {
		slog.InfoContext(ctx, "auth: session expired", "user_id", session.UserID, "expired_at", session.ExpiresAt)
		err = q.DeleteSession(ctx, session.ID)
		if err != nil {
			slog.ErrorContext(ctx, "auth: failed to delete expired session", "user_id", session.UserID, "error", err)
			return nil, &authError{status: http.StatusInternalServerError, message: "failed to delete expired session"}
		}
		return nil, &authError{status: http.StatusUnauthorized, message: "session expired"}
	}

	// extend session if it's getting old (expires within 30 days)
	thirtyDaysFromNow := time.Now().Add(time.Hour * 24 * 30)
	if session.ExpiresAt.Before(thirtyDaysFromNow) {
		newExpiry := time.Now().Add(time.Hour * 24 * 90)
		err = q.UpdateSessionExpiry(ctx, queries.UpdateSessionExpiryParams{
			ID:        session.ID,
			ExpiresAt: newExpiry,
		})
		if err != nil {
			slog.WarnContext(ctx, "auth: failed to extend session", "user_id", session.UserID, "error", err)
		}
	}

	dbUser, err := q.GetUserById(ctx, session.UserID)
	if err != nil {
		slog.ErrorContext(ctx, "auth: failed to fetch user", "user_id", session.UserID, "error", err)
		status, message := http.StatusInternalServerError, "something went wrong"
		if errors.Is(err, pgx.ErrNoRows) {
			status, message = http.StatusUnauthorized, "no user found"
		}
		return nil, &authError{status: status, message: message}
	}

	// log latest app version in profile
	versionAny := ctx.Value(utilities.AppVersionKey)
	version, ok := versionAny.(string)
	userDisplayProperties := dbUser.UserDisplayProperties
	if userDisplayProperties == nil {
		userDisplayProperties = &db.UserDisplayProperties{}
	}
	propertiesChanged := false
	if ok && (userDisplayProperties.LatestAppVersion == nil || semver.Compare(version, *userDisplayProperties.LatestAppVersion) > 0) {
		userDisplayProperties.LatestAppVersion = &version
		propertiesChanged = true
	}

	now := time.Now().UTC()
	if userDisplayProperties.LastLoginDate == nil ||
		userDisplayProperties.LastLoginDate.UTC().Truncate(24*time.Hour).
			Before(now.Truncate(24*time.Hour)) {

		userDisplayProperties.LastLoginDate = &now
		propertiesChanged = true
	}

	if propertiesChanged {
		err = q.UpdateUserDisplayProperties(ctx, queries.UpdateUserDisplayPropertiesParams{
			UserID:                dbUser.UserID,
			UserDisplayProperties: userDisplayProperties,
		})

		if err != nil {
			span.SetStatus(codes.Error, "unable to record latest app version")
			span.RecordError(err)
		}
	}

	publicUser := utilities.MapUserToPublicUser(dbUser)

	span.SetAttributes(attribute.Int("user.id", session.UserID))

	ctx = context.WithValue(ctx, utilities.UserContextKey, publicUser)
	return ctx, nil
}
