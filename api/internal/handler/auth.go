package handler

import (
	"context"
	"errors"
	"strings"
	"time"

	"splajompy.com/api/v2/internal/db"
	"splajompy.com/api/v2/internal/models"
)

func (h *Handler) validateSessionToken(ctx context.Context, authHeader string) (*db.Session, *models.PublicUser, error) {
	if authHeader == "" {
		return nil, nil, errors.New("authorization header required")
	}

	parts := strings.Split(authHeader, "Bearer ")
	if len(parts) != 2 {
		return nil, nil, errors.New("invalid authorization format")
	}
	token := strings.TrimSpace(parts[1])

	session, err := h.queries.GetSessionById(ctx, token)
	if err != nil {
		return nil, nil, errors.New("no session found")
	}

	if time.Now().Unix() >= session.ExpiresAt.Time.Unix() {
		err = h.queries.DeleteSession(ctx, session.ID)
		if err != nil {
			return nil, nil, err
		}
		return nil, nil, errors.New("session expired")
	}

	dbUser, err := h.queries.GetUserById(ctx, session.UserID)
	if err != nil {
		return nil, nil, err
	}

	var user models.PublicUser = models.PublicUser(dbUser)

	return &session, &user, nil
}
