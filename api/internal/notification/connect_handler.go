package notification

import (
	"context"
	"errors"
	"log/slog"

	"connectrpc.com/connect/v2"
	splajompyv1 "splajompy.com/api/v2/gen/splajompy/v1"
	"splajompy.com/api/v2/gen/splajompy/v1/splajompyv1connect"
	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/utilities"
)

type ConnectHandler struct {
	svc *Service
}

func NewConnectHandler(svc *Service) *ConnectHandler {
	return &ConnectHandler{svc: svc}
}

func (h *ConnectHandler) RegisterConnectRoutes(server *connect.Server) {
	splajompyv1connect.RegisterNotificationServiceHandler(server, h)
}

func (h *ConnectHandler) GetUnreadNotificationCount(ctx context.Context, _ *splajompyv1.GetUnreadNotificationCountRequest) (*splajompyv1.GetUnreadNotificationCountResponse, error) {
	user, ok := ctx.Value(utilities.UserContextKey).(models.PublicUser)
	if !ok {
		return nil, connect.NewError(connect.CodeUnauthenticated, "Not authenticated")
	}
	count, err := h.svc.GetUserUnreadNotificationCount(ctx, user)
	if err != nil {
		if ctxErr := ctx.Err(); ctxErr != nil {
			return nil, ctxErr
		}
		slog.ErrorContext(ctx, "failed to get unread notification count", "error", err)
		return nil, connect.NewError(connect.CodeInternal, "Unable to get unread notification count")
	}
	response := &splajompyv1.GetUnreadNotificationCountResponse{}
	response.SetUnreadCount(int64(count))
	return response, nil
}

func (h *ConnectHandler) WatchUnreadNotificationCount(ctx context.Context, _ *splajompyv1.WatchUnreadNotificationCountRequest, stream splajompyv1connect.NotificationServiceWatchUnreadNotificationCountServerStream) error {
	user, ok := ctx.Value(utilities.UserContextKey).(models.PublicUser)
	if !ok {
		return connect.NewError(connect.CodeUnauthenticated, "Not authenticated")
	}
	err := h.svc.WatchUnreadNotificationCount(ctx, user, func(count int) error {
		response := &splajompyv1.WatchUnreadNotificationCountResponse{}
		response.SetUnreadCount(int64(count))
		return stream.Send(response)
	})
	if ctxErr := ctx.Err(); ctxErr != nil {
		return ctxErr
	}
	if errors.Is(err, errUnreadCountUnavailable) {
		slog.ErrorContext(ctx, "failed to watch unread notification count", "error", err)
		return connect.NewError(connect.CodeUnavailable, "Unable to watch unread notification count").WithCause(err)
	}
	return err
}
