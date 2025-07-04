package handler

import (
	"net/http"
	"strconv"

	"splajompy.com/api/v2/internal/utilities"
)

// GET /notifications
func (h *Handler) GetAllNotificationByUserId(w http.ResponseWriter, r *http.Request) {
	currentUser, err := h.getAuthenticatedUser(r)
	if err != nil {
		utilities.HandleError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	offset := 0
	if offsetStr := r.URL.Query().Get("offset"); offsetStr != "" {
		if parsedOffset, err := strconv.Atoi(offsetStr); err == nil && parsedOffset >= 0 {
			offset = parsedOffset
		}
	}

	limit := 20
	if limitStr := r.URL.Query().Get("limit"); limitStr != "" {
		if parsedLimit, err := strconv.Atoi(limitStr); err == nil && parsedLimit > 0 {
			limit = parsedLimit
		}
	}

	notifications, err := h.notificationService.GetNotificationsByUserId(r.Context(), *currentUser, offset, limit)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleSuccess(w, notifications)
}

// POST /notifications/markRead
func (h *Handler) MarkAllNotificationsAsRead(w http.ResponseWriter, r *http.Request) {
	currentUser, err := h.getAuthenticatedUser(r)
	if err != nil {
		utilities.HandleError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	err = h.notificationService.MarkAllNotificationsAsReadForUserId(r.Context(), *currentUser)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleEmptySuccess(w)
}

// POST /notification/{id}/markRead
func (h *Handler) MarkNotificationAsReadById(w http.ResponseWriter, r *http.Request) {
	currentUser, err := h.getAuthenticatedUser(r)
	if err != nil {
		utilities.HandleError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	id, err := h.GetIntPathParam(r, "id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing parameter")
		return
	}

	err = h.notificationService.MarkNotificationAsReadById(r.Context(), *currentUser, id)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleEmptySuccess(w)
}

// GET /notifications/hasUnread
func (h *Handler) HasUnreadNotifications(w http.ResponseWriter, r *http.Request) {
	currentUser, err := h.getAuthenticatedUser(r)
	if err != nil {
		utilities.HandleError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	hasNotifications, err := h.notificationService.UserHasUnreadNotifications(r.Context(), *currentUser)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleSuccess(w, hasNotifications)
}

func (h *Handler) GetUnreadNotificationCount(w http.ResponseWriter, r *http.Request) {
	currentUser, err := h.getAuthenticatedUser(r)
	if err != nil {
		utilities.HandleError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	count, err := h.notificationService.GetUserUnreadNotificationCount(r.Context(), *currentUser)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleSuccess(w, count)
}

// GET /notifications/unread
func (h *Handler) GetUnreadNotificationsByUserId(w http.ResponseWriter, r *http.Request) {
	currentUser, err := h.getAuthenticatedUser(r)
	if err != nil {
		utilities.HandleError(w, http.StatusUnauthorized, "Unauthorized")
		return
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

	notifications, err := h.notificationService.GetUnreadNotificationsByUserId(r.Context(), *currentUser, offset, limit)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleSuccess(w, notifications)
}
