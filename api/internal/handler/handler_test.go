package handler_test

import (
	"context"
	"encoding/json"
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

func (connectHandler) RegisterConnectRoutes(public, withAuth *connect.Server) {
	for _, route := range []struct {
		server    *connect.Server
		procedure string
	}{
		{public, "/test.v1.PublicService/Call"},
		{withAuth, "/test.v1.PrivateService/Call"},
	} {
		route.server.Register(connect.Method{
			Spec: connect.Spec{Procedure: route.procedure, StreamType: connect.StreamTypeUnary},
			Handler: func(_ context.Context, _ connect.Spec, stream connect.ServerStream) error {
				var request splajompyv1.GetUnreadNotificationCountRequest
				if err := stream.Receive(&request); err != nil {
					return err
				}
				return stream.Send(&splajompyv1.GetUnreadNotificationCountResponse{})
			},
		})
	}
}

func TestConnectAuthentication(t *testing.T) {
	mux := http.NewServeMux()
	h := handler.NewHandler(nil, []handler.ConnectRegistrar{connectHandler{}})
	h.RegisterConnectRoutes(mux, nil)

	for _, tc := range []struct {
		path, authorization, version string
		status                       int
		code                         string
	}{
		{path: "/test.v1.PublicService/Call", status: http.StatusOK},
		{path: "/test.v1.PrivateService/Call", status: http.StatusUnauthorized, code: "unauthenticated"},
		{path: "/test.v1.PrivateService/Unknown", status: http.StatusNotImplemented, code: "unimplemented"},
		{path: "/test.v1.PrivateService/Call", authorization: "Basic token", status: http.StatusBadRequest, code: "invalid_argument"},
		{path: "/test.v1.PrivateService/Call", version: "v1.8.0", status: http.StatusBadRequest, code: "failed_precondition"},
		{path: "/test.v1.PublicService/Call", version: "1.8.0", status: http.StatusBadRequest, code: "failed_precondition"},
	} {
		t.Run(tc.path, func(t *testing.T) {
			request := httptest.NewRequest(http.MethodPost, tc.path, strings.NewReader("{}"))
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
