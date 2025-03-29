package handler

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"golang.org/x/crypto/bcrypt"
	"splajompy.com/api/v2/internal/db"
)

// GET /user/{id}/ endpoint
func (h *Handler) GetUserById(w http.ResponseWriter, r *http.Request) {
	currentUser, err := h.getAuthenticatedUser(r)
	if err != nil {
		http.Error(w, err.Error(), http.StatusUnauthorized)
		return
	}

	id, err := h.GetIntPathParam(r, "id")
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	user, err := h.userService.GetUserById(r.Context(), *currentUser, id)
	if err != nil {
		http.Error(w, err.Error(), http.StatusNotFound)
	}

	if err := h.writeJSON(w, user, http.StatusOK); err != nil {
		http.Error(w, "error encoding response", http.StatusInternalServerError)
	}
}

// Credentials for login
type Credentials struct {
	Identifier string `json:"identifier"`
	Password   string `json:"password"`
}

// Login handles the POST /login endpoint
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
	expiresAt := time.Now().Add(time.Hour * 24 * 30) // 30 days

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

	// Return token
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"token": sessionID,
	})
}
