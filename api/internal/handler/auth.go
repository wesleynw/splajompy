package handler

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strings"
	"time"

	db "splajompy.com/api/v2/internal/db/generated"
	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/service"
	"splajompy.com/api/v2/internal/utilities"
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

type LoginRequest struct {
	Identifier string `json:"identifier"`
	Password   string `json:"password"`
}

func (h *Handler) Login(w http.ResponseWriter, r *http.Request) {
	var request LoginRequest
	if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
		utilities.RespondWithError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	var validationErrors []map[string]string

	if request.Identifier == "" {
		validationErrors = append(validationErrors, map[string]string{
			"field":   "email",
			"message": "Username or password is required",
		})
	}

	if request.Password == "" {
		validationErrors = append(validationErrors, map[string]string{
			"field":   "password",
			"message": "Password is required",
		})
	}

	if len(validationErrors) > 0 {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]interface{}{
			"errors": validationErrors,
		})
		return
	}

	response, err := h.authService.LoginWithCredentials(r.Context(), (*service.Credentials)(&request))
	if err != nil {
		switch err {
		case service.ErrUserNotFound:
			validationErrors = append(validationErrors, map[string]string{
				"field":   "identifier",
				"message": "This user doesn't exist",
			})
		case service.ErrInvalidPassword:
			validationErrors = append(validationErrors, map[string]string{
				"field":   "password",
				"message": "Incorrect password",
			})
		default:
			utilities.RespondWithError(w, http.StatusInternalServerError, "Something went wrong")
		}
	}

	if len(validationErrors) > 0 {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]interface{}{
			"errors": validationErrors,
		})
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(response)
}

func (h *Handler) Register(w http.ResponseWriter, r *http.Request) {
	var request service.RegisterRequest
	if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
		utilities.RespondWithError(w, http.StatusBadRequest, "Invalid request body")
	}

	var validationErrors []map[string]string

	if request.Email == "" {
		validationErrors = append(validationErrors, map[string]string{
			"field":   "email",
			"message": "Email is required",
		})
	}

	if request.Username == "" {
		validationErrors = append(validationErrors, map[string]string{
			"field":   "username",
			"message": "Username is required",
		})
	}

	if request.Password == "" {
		validationErrors = append(validationErrors, map[string]string{
			"field":   "password",
			"message": "Password is required",
		})
	}

	if len(validationErrors) > 0 {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]interface{}{
			"errors": validationErrors,
		})
		return
	}

	response, err := h.authService.Register(r.Context(), request)
	if err != nil {
		switch err {
		case service.ErrEmailTaken:
			validationErrors = append(validationErrors, map[string]string{
				"field":   "email",
				"message": "This email address is already taken",
			})
		case service.ErrUsernameTaken:
			validationErrors = append(validationErrors, map[string]string{
				"field":   "username",
				"message": "This username is already taken",
			})
		default:
			utilities.RespondWithError(w, http.StatusInternalServerError, "Error during registration")
			return
		}
	}

	if len(validationErrors) > 0 {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusConflict)
		json.NewEncoder(w).Encode(map[string]interface{}{
			"errors": validationErrors,
		})
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(response)
}

type OTCRequest struct {
	Identifier string `json:"identifier"`
}

func (h *Handler) GenerateOTC(w http.ResponseWriter, r *http.Request) {
	var request OTCRequest
	if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
		utilities.RespondWithError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	err := h.authService.ProcessOTC(r.Context(), request.Identifier)
	if err != nil {
		utilities.RespondWithError(w, http.StatusInternalServerError, "Something went wrong")
	}
}
