package wrapped

import (
	"net/http"

	"splajompy.com/api/v2/internal/utilities"
)

type Handler struct {
	svc *Service
}

func NewHandler(svc *Service) *Handler {
	return &Handler{svc: svc}
}

func (h *Handler) WrappedPrecomputation(w http.ResponseWriter, r *http.Request) {
	currentUser := utilities.GetAuthenticatedUser(r)
	if currentUser.UserID != 6 { // me
		utilities.HandleError(w, http.StatusUnauthorized, "you're not allowed to do this")
		return
	}

	data, err := h.svc.PrecomputeWrappedForAllUsers(r.Context())
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, err.Error())
		return
	}

	utilities.HandleSuccess(w, data)
}

func (h *Handler) GetIsUserEligibleForWrapped(w http.ResponseWriter, r *http.Request) {
	currentUser := utilities.GetAuthenticatedUser(r)

	isEligible, err := h.svc.IsUserEligibleForWrapped(r.Context(), currentUser.UserID)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, err.Error())
		return
	}

	utilities.HandleSuccess(w, isEligible)
}

func (h *Handler) GetWrappedActivityData(w http.ResponseWriter, r *http.Request) {
	currentUser := utilities.GetAuthenticatedUser(r)

	data, err := h.svc.GetPrecomputedWrappedDataByUserId(r.Context(), currentUser.UserID)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, err.Error())
		return
	}

	utilities.HandleSuccess(w, data)
}
