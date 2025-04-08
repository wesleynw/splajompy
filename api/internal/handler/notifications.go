package handler

import (
	"net/http"
	"strconv"
)

// GET /notifications
func (h *Handler) GetAllNotificationByUserId(w http.ResponseWriter, r *http.Request) {
	currentUser, err := h.getAuthenticatedUser(r)
	if err != nil {
		http.Error(w, err.Error(), http.StatusUnauthorized)
	}

	offset := 0
	if offsetStr := r.URL.Query().Get("offset"); offsetStr != "" {
		if parsedOffset, err := strconv.Atoi(offsetStr); err == nil && parsedOffset >= 0 {
			offset = parsedOffset
		}
	}

	limit := 10
	if limitStr := r.URL.Query().Get("limit"); limitStr != "" {
		if parsedLimit, err := strconv.Atoi(limitStr); err == nil && parsedLimit > 0 {
			limit = parsedLimit
		}
	}

	notifications, err := h.notifificationService.GetNotificationsByUserId(r.Context(), *currentUser, offset, limit)
	if err != nil {
		http.Error(w, "Unable to retrieve notifications", http.StatusInternalServerError)
	}

	if err = h.writeJSON(w, notifications, http.StatusOK); err != nil {
		http.Error(w, "Error encoding response", http.StatusInternalServerError)
	}
}

// POST /notifications/markRead
func (h *Handler) MarkAllNotificationsAsRead(w http.ResponseWriter, r *http.Request) {
	currentUser, err := h.getAuthenticatedUser(r)
	if err != nil {
		http.Error(w, err.Error(), http.StatusUnauthorized)
	}

	err = h.notifificationService.MarkAllNotificationsAsReadForUserId(r.Context(), *currentUser)
	if err != nil {
		http.Error(w, "Unable to mark notifications as read", http.StatusInternalServerError)
	}
}

// POST /notification/{id}/markRead
func (h *Handler) MarkNotificationAsReadById(w http.ResponseWriter, r *http.Request) {
	currentUser, err := h.getAuthenticatedUser(r)
	if err != nil {
		http.Error(w, err.Error(), http.StatusUnauthorized)
	}

	id, err := h.GetIntPathParam(r, "id")
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	err = h.notifificationService.MarkNotificationAsReadById(r.Context(), *currentUser, id)
	if err != nil {
		http.Error(w, "Unable to mark notification as read", http.StatusInternalServerError)
	}
}

// GET /notifications/hasUnread
func (h *Handler) HasUnreadNotifications(w http.ResponseWriter, r *http.Request) {
	currentUser, err := h.getAuthenticatedUser(r)
	if err != nil {
		http.Error(w, err.Error(), http.StatusUnauthorized)
	}

	hasNotifications, err := h.notifificationService.UserHasUnreadNotifications(r.Context(), *currentUser)
	if err != nil {
		http.Error(w, "Unable to mark notification as read", http.StatusInternalServerError)
	}

	if err = h.writeJSON(w, hasNotifications, http.StatusOK); err != nil {
		http.Error(w, "Error encoding response", http.StatusInternalServerError)
	}
}
