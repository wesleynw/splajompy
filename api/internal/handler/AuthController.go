package handler

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"splajompy.com/api/v2/internal/db/queries"
	"strings"
	"time"

	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/service"
	"splajompy.com/api/v2/internal/utilities"
)

func (h *Handler) getAuthenticatedUser(r *http.Request) (*models.PublicUser, error) {
	_, user, err := h.validateSessionToken(r.Context(), r.Header.Get("Authorization"))
	return user, err
}

func (h *Handler) validateSessionToken(ctx context.Context, authHeader string) (*queries.Session, *models.PublicUser, error) {
	if authHeader == "" {
		return nil, nil, errors.New("authorization header required")
	}

	parts := strings.Split(authHeader, "Bearer ")
	if len(parts) != 2 {
		return nil, nil, errors.New("invalid authorization format")
	}
	token := strings.ReplaceAll(strings.TrimSpace(parts[1]), `\/`, `/`)

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

	var user = utilities.MapUserToPublicUser(dbUser)
	return &session, &user, nil
}

type LoginRequest struct {
	Identifier string `json:"identifier"`
	Password   string `json:"password"`
}

// Login authenticates a user with email/username and password.
// It validates credentials, creates a session, and returns an auth token.
//
// Request body should contain:
//   - identifier: email or username
//   - password: user's password
//
// Returns 200 with auth token on success, 400 for invalid credentials.
func (h *Handler) Login(w http.ResponseWriter, r *http.Request) {
	var request LoginRequest
	if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	if request.Identifier == "" || request.Password == "" {
		utilities.HandleError(w, http.StatusBadRequest, "Validation error") // TODO: more comprehensive validation errors
		return
	}

	response, err := h.authService.LoginWithCredentials(r.Context(), (*service.Credentials)(&request))
	if err != nil {
		switch err {
		case service.ErrUserNotFound:
			utilities.HandleError(w, http.StatusBadRequest, "This user doesn't exist")
		case service.ErrInvalidPassword:
			utilities.HandleError(w, http.StatusBadRequest, "Incorrect password")
		default:
			utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		}
		return
	}

	utilities.HandleSuccess(w, response)
}

type RegisterRequest struct {
	Email    string `json:"email"`
	Username string `json:"username"`
	Password string `json:"password"`
}

func (h *Handler) Register(w http.ResponseWriter, r *http.Request) {
	var request RegisterRequest
	if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	if request.Email == "" || request.Username == "" || request.Password == "" {
		utilities.HandleError(w, http.StatusBadRequest, "Validation error") // TODO: more comprehensive validation errors
		return
	}

	response, err := h.authService.Register(r.Context(), request.Email, request.Username, request.Password)
	if err != nil {
		switch err {
		case service.ErrEmailTaken:
			utilities.HandleError(w, http.StatusBadRequest, "An account already exists with this email")
		case service.ErrUsernameTaken:
			utilities.HandleError(w, http.StatusBadRequest, "An account already exists with this username")
		default:
			utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		}
		return
	}

	utilities.HandleSuccess(w, response)
}

type GenerateOtcRequest struct {
	Identifier string `json:"identifier"`
}

func (h *Handler) GenerateOTC(w http.ResponseWriter, r *http.Request) {
	var request GenerateOtcRequest
	if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	err := h.authService.ProcessOTC(r.Context(), request.Identifier)
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Unable to generate code")
		return
	}

	utilities.HandleEmptySuccess(w)
}

type VerifyOtcRequest struct {
	Code       string `json:"code"`
	Identifier string `json:"identifier"`
}

func (h *Handler) VerifyOTC(w http.ResponseWriter, r *http.Request) {
	var request VerifyOtcRequest
	if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	response, err := h.authService.VerifyOTCCode(r.Context(), request.Identifier, request.Code)
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Unable to verify code")
		return
	}

	utilities.HandleSuccess(w, response)
}

type DeleteAccountRequest struct {
	Password string `json:"password"`
}

// DeleteAccount deletes the current users account, given the correct password.
//
// Request body should contain:
//   - password: user's password
//
// Returns 200 with auth token on success, 400 for invalid credentials.
func (h *Handler) DeleteAccount(w http.ResponseWriter, r *http.Request) {
	currentUser, err := h.getAuthenticatedUser(r)
	if err != nil {
		utilities.HandleError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	var request DeleteAccountRequest
	if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	success, err := h.authService.VerifyPassword(r.Context(), currentUser.Username, request.Password)
	if err != nil || !success {
		utilities.HandleError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	err = h.authService.DeleteAccount(r.Context(), *currentUser)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleEmptySuccess(w)
}
