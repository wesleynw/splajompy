package handler

import (
	"encoding/json"
	"net/http"
	"splajompy.com/api/v2/internal/service"
	"splajompy.com/api/v2/internal/utilities"
)

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

	response, err := h.authService.Register(r.Context(), request.Email, request.Username, request.Password)
	if err != nil {
		switch err {
		case service.ErrEmailTaken:
			utilities.HandleError(w, http.StatusBadRequest, "An account already exists with this email")
		case service.ErrUsernameTaken:
			utilities.HandleError(w, http.StatusBadRequest, "An account already exists with this username")
		case service.ErrUsernameInvalidFormat:
			utilities.HandleError(w, http.StatusBadRequest, "Username can only contain letters and numbers")
		case service.ErrUsernameTooShort:
			utilities.HandleError(w, http.StatusBadRequest, "Username must be at least 1 character")
		case service.ErrPasswordTooShort:
			utilities.HandleError(w, http.StatusBadRequest, "Password must be at least 8 characters")
		case service.ErrInvalidEmail:
			utilities.HandleError(w, http.StatusBadRequest, "Please enter a valid email address")
		default:
			utilities.HandleError(w, http.StatusBadRequest, err.Error())
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
	var request DeleteAccountRequest
	if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	user := h.getAuthenticatedUser(r)

	success, err := h.authService.VerifyPassword(r.Context(), user.Username, request.Password)
	if err != nil || !success {
		utilities.HandleError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	err = h.authService.DeleteAccount(r.Context(), *user)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleEmptySuccess(w)
}
