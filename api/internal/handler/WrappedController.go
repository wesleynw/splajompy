package handler

import (
	"net/http"

	"splajompy.com/api/v2/internal/utilities"
)

type WrappedPrecomputationResponse struct {
	Succeeded []int
	Failed    []int
}

func (h *Handler) WrappedPrecomputation(w http.ResponseWriter, r *http.Request) {
	// currentUser := h.getAuthenticatedUser(r)
	// if currentUser.UserID != 6 { // me
	// 	utilities.HandleError(w, http.StatusUnauthorized, "")
	// 	return
	// }

	succeeded, failed, err := h.wrappedService.PrecomputeWrappedForAllUsers(r.Context())
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, err.Error())
		return
	}

	response := WrappedPrecomputationResponse{
		Succeeded: succeeded,
		Failed:    failed,
	}

	utilities.HandleSuccess(w, response)
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
