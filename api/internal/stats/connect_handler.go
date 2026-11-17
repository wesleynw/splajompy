package stats

import (
	"context"

	"connectrpc.com/connect/v2"
	splajompyv1 "splajompy.com/api/v2/gen/splajompy/v1"
	"splajompy.com/api/v2/gen/splajompy/v1/splajompyv1connect"
)

type ConnectHandler struct {
	svc *Service
}

func NewConnectHandler(svc *Service) *ConnectHandler {
	return &ConnectHandler{svc: svc}
}

func (h *ConnectHandler) RegisterRPCRoutes(public, withAuth *connect.Server) {
	splajompyv1connect.RegisterStatsServiceHandler(public, h)
}

func (h *ConnectHandler) GetHealth(ctx context.Context, request *splajompyv1.GetHealthRequest) (*splajompyv1.GetHealthResponse, error) {
	response := new(splajompyv1.GetHealthResponse)
	response.SetHealthy(true)

	return response, nil
}
