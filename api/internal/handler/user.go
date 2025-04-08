package handler

import (
	"net/http"
)

// GET /user/{id}
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

// POST /follow/{user_id}
func (h *Handler) FollowUser(w http.ResponseWriter, r *http.Request) {
	currentUser, err := h.getAuthenticatedUser(r)
	if err != nil {
		http.Error(w, err.Error(), http.StatusUnauthorized)
		return
	}

	userId, err := h.GetIntPathParam(r, "user_id")
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
	}

	err = h.userService.FollowUser(r.Context(), *currentUser, userId)
	if err != nil {
		http.Error(w, "Unable to follow user", http.StatusInternalServerError)
	}
}

func (h *Handler) UnfollowUser(w http.ResponseWriter, r *http.Request) {
	currentUser, err := h.getAuthenticatedUser(r)
	if err != nil {
		http.Error(w, err.Error(), http.StatusUnauthorized)
		return
	}

	userId, err := h.GetIntPathParam(r, "user_id")
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
	}

	err = h.userService.UnfollowUser(r.Context(), *currentUser, userId)
	if err != nil {
		http.Error(w, "Unable to unfollow user", http.StatusInternalServerError)
	}
}
