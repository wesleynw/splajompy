package handler

import (
	"net/http"
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
