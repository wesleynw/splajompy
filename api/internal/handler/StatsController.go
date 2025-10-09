package handler

import (
	"net/http"

	"splajompy.com/api/v2/internal/utilities"
)

func (h *Handler) GetAppStats(w http.ResponseWriter, r *http.Request) {
	stats, err := h.statsService.GetAppStats(r.Context())
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleSuccess(w, stats)
}
