package handler

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"golang.org/x/crypto/bcrypt"
	"splajompy.com/api/v2/internal/db"
	"splajompy.com/api/v2/internal/models"
)

func (h *Handler) getAuthenticatedUser(r *http.Request) (*models.PublicUser, error) {
	_, user, err := h.validateSessionToken(r.Context(), r.Header.Get("Authorization"))
	return user, err
}

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

	var user = models.PublicUser(dbUser)

	return &session, &user, nil
}

type Credentials struct {
	Identifier string `json:"identifier"`
	Password   string `json:"password"`
}

// POST /login endpoint
func (h *Handler) Login(w http.ResponseWriter, r *http.Request) {
	var creds Credentials
	if err := json.NewDecoder(r.Body).Decode(&creds); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	user, err := h.queries.GetUserWithPasswordByIdentifier(r.Context(), creds.Identifier)
	if err != nil {
		if err == pgx.ErrNoRows {
			http.Error(w, "User not found", http.StatusNotFound)
		} else {
			http.Error(w, "Error fetching user", http.StatusInternalServerError)
		}
		return
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(creds.Password)); err != nil {
		http.Error(w, "Incorrect password", http.StatusUnauthorized)
		return
	}

	sessionID := uuid.NewString()
	expiresAt := time.Now().Add(time.Hour * 24 * 90) // 90 days

	var expiresAtPg pgtype.Timestamp
	expiresAtPg.Time = expiresAt
	expiresAtPg.Valid = true

	err = h.queries.CreateSession(r.Context(), db.CreateSessionParams{
		ID:        sessionID,
		UserID:    user.UserID,
		ExpiresAt: expiresAtPg,
	})
	if err != nil {
		http.Error(w, "Failed to create session", http.StatusInternalServerError)
		return
	}

	var publicUser = models.PublicUser{
		UserID:    user.UserID,
		Username:  user.Username,
		Email:     user.Email,
		Name:      user.Name,
		CreatedAt: user.CreatedAt,
	}

	response := struct {
		Token string            `json:"token"`
		User  models.PublicUser `json:"user"`
	}{
		Token: sessionID,
		User:  publicUser,
	}

	if err := h.writeJSON(w, response, http.StatusOK); err != nil {
		http.Error(w, "error encoding response", http.StatusInternalServerError)
	}
}
