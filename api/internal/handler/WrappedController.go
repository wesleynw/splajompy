package handler

import (
	"net/http"

	"splajompy.com/api/v2/internal/utilities"
)

func (h *Handler) WrappedPrecomputation(w http.ResponseWriter, r *http.Request) {
	currentUser := h.getAuthenticatedUser(r)
	if currentUser.UserID != 6 { // me
		utilities.HandleError(w, http.StatusUnauthorized, "you're not allowed to do this")
		return
	}

	data, err := h.wrappedService.PrecomputeWrappedForAllUsers(r.Context())
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, err.Error())
		return
	}

	utilities.HandleSuccess(w, data)
}

func (h *Handler) GetIsUserEligibleForWrapped(w http.ResponseWriter, r *http.Request) {
	currentUser := h.getAuthenticatedUser(r)

	isEligible, err := h.wrappedService.IsUserEligibleForWrapped(r.Context(), currentUser.UserID)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, err.Error())
		return
	}

	utilities.HandleSuccess(w, isEligible)
}

func (h *Handler) GetWrappedActivityData(w http.ResponseWriter, r *http.Request) {
	currentUser := h.getAuthenticatedUser(r)

	data, err := h.wrappedService.GetPrecomputedWrappedDataByUserId(r.Context(), currentUser.UserID)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, err.Error())
		return
	}

	utilities.HandleSuccess(w, data)
}
