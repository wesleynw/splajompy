package handler_test

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"connectrpc.com/connect/v2"
	"github.com/stretchr/testify/require"
	splajompyv1 "splajompy.com/api/v2/gen/splajompy/v1"
	"splajompy.com/api/v2/internal/handler"
)

type connectHandler struct{}

func (connectHandler) RegisterConnectRoutes(server *connect.Server) {
	server.Register(connect.Method{
		Spec: connect.Spec{Procedure: "/test.v1.TestService/Call", StreamType: connect.StreamTypeUnary},
		Handler: func(_ context.Context, _ connect.Spec, stream connect.ServerStream) error {
			var request splajompyv1.GetUnreadNotificationCountRequest
			if err := stream.Receive(&request); err != nil {
				return err
			}
			return stream.Send(&splajompyv1.GetUnreadNotificationCountResponse{})
		},
	})
}

func TestConnectAuthentication(t *testing.T) {
	mux := http.NewServeMux()
	h := handler.NewHandler(nil, []handler.ConnectRegistrar{connectHandler{}})
	h.RegisterConnectRoutes(mux, nil)
	canceled, cancel := context.WithCancel(t.Context())
	cancel()
	expired, cancel := context.WithDeadline(t.Context(), time.Now().Add(-time.Second))
	defer cancel()

	for _, tc := range []struct {
		path, authorization, version string
		ctx                          context.Context
		status                       int
		code                         string
	}{
		{path: "/test.v1.TestService/Call", status: http.StatusUnauthorized, code: "unauthenticated"},
		{path: "/test.v1.TestService/Unknown", status: http.StatusNotImplemented, code: "unimplemented"},
		{path: "/test.v1.TestService/Call", authorization: "Basic token", status: http.StatusBadRequest, code: "invalid_argument"},
		{path: "/test.v1.TestService/Call", version: "v1.8.0", status: http.StatusBadRequest, code: "failed_precondition"},
		{path: "/test.v1.TestService/Call", version: "1.8.0", status: http.StatusBadRequest, code: "failed_precondition"},
		{path: "/test.v1.TestService/Call", ctx: canceled, status: 499, code: "canceled"},
		{path: "/test.v1.TestService/Call", ctx: expired, status: http.StatusGatewayTimeout, code: "deadline_exceeded"},
	} {
		t.Run(tc.path, func(t *testing.T) {
			ctx := tc.ctx
			if ctx == nil {
				ctx = t.Context()
			}
			request := httptest.NewRequestWithContext(ctx, http.MethodPost, tc.path, strings.NewReader("{}"))
			request.Header.Set("Content-Type", "application/json")
			request.Header.Set("Authorization", tc.authorization)
			request.Header.Set("X-App-Version", tc.version)
			response := httptest.NewRecorder()
			mux.ServeHTTP(response, request)

			require.Equal(t, tc.status, response.Code)
			if tc.code != "" {
				var body struct{ Code string }
				require.NoError(t, json.Unmarshal(response.Body.Bytes(), &body))
				require.Equal(t, tc.code, body.Code)
			}
		})
	}
}
