package notification

import (
	"net/http"
	"strconv"
	"time"

	"go.opentelemetry.io/otel/codes"
	"go.opentelemetry.io/otel/trace"
	"splajompy.com/api/v2/internal/utilities"
)

type Handler struct {
	svc *Service
}

func NewHandler(svc *Service) *Handler {
	return &Handler{svc: svc}
}

func (h *Handler) RegisterRoutes(withAuth func(string, func(http.ResponseWriter, *http.Request))) {
	withAuth("POST /notifications/markRead", h.MarkAllNotificationsAsRead)
	withAuth("POST /notifications/{id}/markRead", h.MarkNotificationAsReadById)
	withAuth("GET /notifications/hasUnread", h.HasUnreadNotifications)
	withAuth("GET /notifications/unreadCount", h.GetUnreadNotificationCount)
	withAuth("GET /notifications/read/time", h.GetReadNotificationsByUserIdWithTimeOffset)
	withAuth("GET /notifications/unread/time", h.GetUnreadNotificationsByUserIdWithTimeOffset)
}

func (h *Handler) MarkAllNotificationsAsRead(w http.ResponseWriter, r *http.Request) {
	currentUser := utilities.GetAuthenticatedUser(r)

	err := h.svc.MarkAllNotificationsAsReadForUserId(r.Context(), *currentUser)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleEmptySuccess(w)
}

func (h *Handler) MarkNotificationAsReadById(w http.ResponseWriter, r *http.Request) {
	currentUser := utilities.GetAuthenticatedUser(r)

	id, err := utilities.GetIntPathParam(r, "id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing parameter")
		return
	}

	err = h.svc.MarkNotificationAsReadById(r.Context(), *currentUser, id)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleEmptySuccess(w)
}

func (h *Handler) HasUnreadNotifications(w http.ResponseWriter, r *http.Request) {
	currentUser := utilities.GetAuthenticatedUser(r)

	hasNotifications, err := h.svc.UserHasUnreadNotifications(r.Context(), *currentUser)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleSuccess(w, hasNotifications)
}

func (h *Handler) GetUnreadNotificationCount(w http.ResponseWriter, r *http.Request) {
	currentUser := utilities.GetAuthenticatedUser(r)

	count, err := h.svc.GetUserUnreadNotificationCount(r.Context(), *currentUser)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleSuccess(w, count)
}

func (h *Handler) GetReadNotificationsByUserIdWithTimeOffset(w http.ResponseWriter, r *http.Request) {
	currentUser := utilities.GetAuthenticatedUser(r)

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

	notifications, err := h.svc.GetReadNotificationsByUserIdWithTimeOffset(r.Context(), *currentUser, beforeTime, limit, notificationType)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleSuccess(w, notifications)
}

func (h *Handler) GetUnreadNotificationsByUserIdWithTimeOffset(w http.ResponseWriter, r *http.Request) {
	currentUser := utilities.GetAuthenticatedUser(r)

	span := trace.SpanFromContext(r.Context())

	beforeTimeStr := r.URL.Query().Get("before_time")
	var beforeTime time.Time
	var err error
	if beforeTimeStr != "" {
		beforeTime, err = time.Parse(time.RFC3339, beforeTimeStr)
		if err != nil {
			span.SetStatus(codes.Error, err.Error())
			span.RecordError(err)
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

	notifications, err := h.svc.GetUnreadNotificationsByUserIdWithTimeOffset(r.Context(), *currentUser, beforeTime, limit, notificationType)
	if err != nil {
		span.SetStatus(codes.Error, err.Error())
		span.RecordError(err)
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleSuccess(w, notifications)
}
