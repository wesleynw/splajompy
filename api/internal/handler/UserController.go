package handler

import (
	"encoding/json"
	"net/http"
	"splajompy.com/api/v2/internal/utilities"
)

func (h *Handler) GetUserById(w http.ResponseWriter, r *http.Request) {
	currentUser, err := h.getAuthenticatedUser(r)
	if err != nil {
		utilities.HandleError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	id, err := h.GetIntPathParam(r, "id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing ID parameter")
		return
	}

	user, err := h.userService.GetUserById(r.Context(), *currentUser, id)
	if err != nil {
		utilities.HandleError(w, http.StatusNotFound, "This user doesn't exist")
		return
	}

	isBlocking, err := h.userService.IsBlockingUser(r.Context(), user.UserID, currentUser.UserID)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	if isBlocking {
		utilities.HandleError(w, http.StatusNotFound, "This user doesn't exist")
		return
	}

	utilities.HandleSuccess(w, user)
}

func (h *Handler) SearchUsers(w http.ResponseWriter, r *http.Request) {
	currentUser, err := h.getAuthenticatedUser(r)
	if err != nil {
		utilities.HandleError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	prefix := r.URL.Query().Get("prefix")
	if prefix == "" {
		utilities.HandleError(w, http.StatusBadRequest, "Missing prefix")
		return
	}

	users, err := h.userService.GetUserByUsernamePrefix(r.Context(), prefix, currentUser.UserID)
	if err != nil {
		utilities.HandleError(w, http.StatusNotFound, "This user doesn't exist")
		return
	}

	utilities.HandleSuccess(w, users)
}

func (h *Handler) FollowUser(w http.ResponseWriter, r *http.Request) {
	currentUser, err := h.getAuthenticatedUser(r)
	if err != nil {
		utilities.HandleError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	userId, err := h.GetIntPathParam(r, "user_id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing ID parameter")
		return
	}

	err = h.userService.FollowUser(r.Context(), *currentUser, userId)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleEmptySuccess(w)
}

func (h *Handler) UnfollowUser(w http.ResponseWriter, r *http.Request) {
	currentUser, err := h.getAuthenticatedUser(r)
	if err != nil {
		utilities.HandleError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	userId, err := h.GetIntPathParam(r, "user_id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing ID parameter")
		return
	}

	err = h.userService.UnfollowUser(r.Context(), *currentUser, userId)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleEmptySuccess(w)
}

type UpdateProfileRequest struct {
	Name string `json:"name"`
	Bio  string `json:"bio"`
}

func (h *Handler) UpdateProfile(w http.ResponseWriter, r *http.Request) {
	currentUser, err := h.getAuthenticatedUser(r)
	if err != nil {
		utilities.HandleError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	var request = new(UpdateProfileRequest)
	if err := json.NewDecoder(r.Body).Decode(request); err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}

	err = h.userService.UpdateProfile(r.Context(), currentUser.UserID, &request.Name, &request.Bio)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleEmptySuccess(w)
}

func (h *Handler) BlockUser(w http.ResponseWriter, r *http.Request) {
	currentUser, err := h.getAuthenticatedUser(r)
	if err != nil {
		utilities.HandleError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	userId, err := h.GetIntPathParam(r, "user_id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing user ID parameter")
		return
	}

	err = h.userService.BlockUser(r.Context(), *currentUser, userId)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleEmptySuccess(w)
}

func (h *Handler) UnblockUser(w http.ResponseWriter, r *http.Request) {
	currentUser, err := h.getAuthenticatedUser(r)
	if err != nil {
		utilities.HandleError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	userId, err := h.GetIntPathParam(r, "user_id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing user ID parameter")
		return
	}

	err = h.userService.UnblockUser(r.Context(), *currentUser, userId)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleEmptySuccess(w)
}
