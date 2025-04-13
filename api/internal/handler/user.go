package handler

import (
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

	utilities.HandleSuccess(w, user)
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
