package notification

import (
	"context"
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

func (h *ConnectHandler) RegisterConnectRoutes(public, withAuth *connect.Server) {
	splajompyv1connect.RegisterNotificationServiceHandler(withAuth, h)
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
	return &splajompyv1.GetUnreadNotificationCountResponse{UnreadCount: int64(count)}, nil
}
