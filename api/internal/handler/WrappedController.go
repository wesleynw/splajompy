package handler

import (
	"net/http"

	"splajompy.com/api/v2/internal/utilities"
)

func (h *Handler) GetWrappedActivityData(w http.ResponseWriter, r *http.Request) {
	currentUser := h.getAuthenticatedUser(r)

	activity, err := h.wrappedService.GetUserActivityData(r.Context(), currentUser.UserID)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "something went wrong")
		return
	}

	utilities.HandleSuccess(w, activity)
}
