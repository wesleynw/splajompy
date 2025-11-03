package handler

import (
	"net/http"
	"strconv"
	"time"

	"splajompy.com/api/v2/internal/utilities"
)

// GetAllNotificationByUserId GET /notifications
func (h *Handler) GetAllNotificationByUserId(w http.ResponseWriter, r *http.Request) {
	currentUser := h.getAuthenticatedUser(r)

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

// MarkAllNotificationsAsRead POST /notifications/markRead
func (h *Handler) MarkAllNotificationsAsRead(w http.ResponseWriter, r *http.Request) {
	currentUser := h.getAuthenticatedUser(r)

	err := h.notificationService.MarkAllNotificationsAsReadForUserId(r.Context(), *currentUser)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleEmptySuccess(w)
}

// MarkNotificationAsReadById POST /notification/{id}/markRead
func (h *Handler) MarkNotificationAsReadById(w http.ResponseWriter, r *http.Request) {
	currentUser := h.getAuthenticatedUser(r)

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

// HasUnreadNotifications GET /notifications/hasUnread
func (h *Handler) HasUnreadNotifications(w http.ResponseWriter, r *http.Request) {
	currentUser := h.getAuthenticatedUser(r)

	hasNotifications, err := h.notificationService.UserHasUnreadNotifications(r.Context(), *currentUser)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleSuccess(w, hasNotifications)
}

func (h *Handler) GetUnreadNotificationCount(w http.ResponseWriter, r *http.Request) {
	currentUser := h.getAuthenticatedUser(r)

	count, err := h.notificationService.GetUserUnreadNotificationCount(r.Context(), *currentUser)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleSuccess(w, count)
}

// GetUnreadNotificationsByUserId GET /notifications/unread
func (h *Handler) GetUnreadNotificationsByUserId(w http.ResponseWriter, r *http.Request) {
	currentUser := h.getAuthenticatedUser(r)

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

// GetReadNotificationsByUserIdWithTimeOffset GET /notifications/read/time
func (h *Handler) GetReadNotificationsByUserIdWithTimeOffset(w http.ResponseWriter, r *http.Request) {
	currentUser := h.getAuthenticatedUser(r)

	beforeTimeStr := r.URL.Query().Get("before_time")
	var beforeTime time.Time
	var err error
	if beforeTimeStr != "" {
		beforeTime, err = time.Parse(time.RFC3339, beforeTimeStr)
		if err != nil {
			utilities.HandleError(w, http.StatusBadRequest, "Invalid before_time format, expected RFC3339")
			return
		}
	} else {
		beforeTime = time.Now()
	}

	limit := 30
	if limitStr := r.URL.Query().Get("limit"); limitStr != "" {
		if parsedLimit, err := strconv.Atoi(limitStr); err == nil && parsedLimit > 0 {
			limit = parsedLimit
		}
	}

	var notificationType *string
	if notifTypeStr := r.URL.Query().Get("notification_type"); notifTypeStr != "" {
		notificationType = &notifTypeStr
	}

	notifications, err := h.notificationService.GetReadNotificationsByUserIdWithTimeOffset(r.Context(), *currentUser, beforeTime, limit, notificationType)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleSuccess(w, notifications)
}

// GetUnreadNotificationsByUserIdWithTimeOffset GET /notifications/unread/time
func (h *Handler) GetUnreadNotificationsByUserIdWithTimeOffset(w http.ResponseWriter, r *http.Request) {
	currentUser := h.getAuthenticatedUser(r)

	beforeTimeStr := r.URL.Query().Get("before_time")
	var beforeTime time.Time
	var err error
	if beforeTimeStr != "" {
		beforeTime, err = time.Parse(time.RFC3339, beforeTimeStr)
		if err != nil {
			utilities.HandleError(w, http.StatusBadRequest, "Invalid before_time format, expected RFC3339")
			return
		}
	} else {
		beforeTime = time.Now()
	}

	limit := 30
	if limitStr := r.URL.Query().Get("limit"); limitStr != "" {
		if parsedLimit, err := strconv.Atoi(limitStr); err == nil && parsedLimit > 0 {
			limit = parsedLimit
		}
	}

	var notificationType *string
	if notifTypeStr := r.URL.Query().Get("notification_type"); notifTypeStr != "" {
		notificationType = &notifTypeStr
	}

	notifications, err := h.notificationService.GetUnreadNotificationsByUserIdWithTimeOffset(r.Context(), *currentUser, beforeTime, limit, notificationType)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleSuccess(w, notifications)
}
