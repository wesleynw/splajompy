package handler_test

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"connectrpc.com/connect/v2"
	"github.com/stretchr/testify/require"
	splajompyv1 "splajompy.com/api/v2/gen/splajompy/v1"
	"splajompy.com/api/v2/internal/handler"
)

type connectHandler struct{}

func (connectHandler) RegisterConnectRoutes(server *connect.Server) []string {
	for _, procedure := range []string{"/test.v1.Service/Public", "/test.v1.Service/Private"} {
		server.Register(connect.Method{
			Spec: connect.Spec{Procedure: procedure, StreamType: connect.StreamTypeUnary},
			Handler: func(_ context.Context, _ connect.Spec, stream connect.ServerStream) error {
				var request splajompyv1.GetUnreadNotificationCountRequest
				if err := stream.Receive(&request); err != nil {
					return err
				}
				return stream.Send(&splajompyv1.GetUnreadNotificationCountResponse{})
			},
		})
	}
	return []string{"/test.v1.Service/Public"}
}

func TestConnectAuthentication(t *testing.T) {
	mux := http.NewServeMux()
	h := handler.NewHandler(nil, []handler.ConnectRegistrar{connectHandler{}})
	h.RegisterConnectRoutes(mux, nil)

	for _, tc := range []struct {
		path   string
		status int
	}{
		{path: "/test.v1.Service/Public", status: http.StatusOK},
		{path: "/test.v1.Service/Private", status: http.StatusUnauthorized},
		{path: "/test.v1.Service/Unknown", status: http.StatusUnauthorized},
	} {
		t.Run(tc.path, func(t *testing.T) {
			request := httptest.NewRequest(http.MethodPost, tc.path, strings.NewReader("{}"))
			request.Header.Set("Content-Type", "application/json")
			response := httptest.NewRecorder()
			mux.ServeHTTP(response, request)

			require.Equal(t, tc.status, response.Code)
			if tc.status == http.StatusUnauthorized {
				require.JSONEq(t, `{"code":"unauthenticated","message":"Unauthorized"}`, response.Body.String())
			}
		})
	}
}
