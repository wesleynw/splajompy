package stats

import (
	"net/http"

	"splajompy.com/api/v2/internal/middleware"
	"splajompy.com/api/v2/internal/utilities"
)

type Handler struct {
	svc *Service
}

func NewHandler(svc *Service) *Handler {
	return &Handler{svc: svc}
}

func (h *Handler) RegisterRoutes(withAuth func(string, func(http.ResponseWriter, *http.Request))) {
}

func (h *Handler) GetAppStats(w http.ResponseWriter, r *http.Request) {
	stats, err := h.statsService.GetAppStats(r.Context())
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleSuccess(w, stats)
}

func (h *Handler) GetAppHealth(w http.ResponseWriter, r *http.Request) {
	utilities.HandleEmptySuccess(w)
}

func (h *Handler) GetVersionAvailability(w http.ResponseWriter, r *http.Request) {
	utilities.HandleSuccess(w, middleware.MinimumAppVersion)
}
