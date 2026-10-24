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
	"connectrpc.com/connect/v2/connecthttp"
	"connectrpc.com/connect/v2/connectproto"
	"github.com/stretchr/testify/require"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/trace"
	"google.golang.org/genproto/googleapis/rpc/errdetails"
	splajompyv1 "splajompy.com/api/v2/gen/splajompy/v1"
	"splajompy.com/api/v2/gen/splajompy/v1/splajompyv1connect"
	"splajompy.com/api/v2/internal/handler"
	"splajompy.com/api/v2/internal/middleware"
	"splajompy.com/api/v2/internal/testutil"
)

type connectHandler struct{}

func (h connectHandler) RegisterConnectRoutes(server *connect.Server) {
	splajompyv1connect.RegisterNotificationServiceHandler(server, h)
}

func (connectHandler) GetUnreadNotificationCount(context.Context, *splajompyv1.GetUnreadNotificationCountRequest) (*splajompyv1.GetUnreadNotificationCountResponse, error) {
	return &splajompyv1.GetUnreadNotificationCountResponse{}, nil
}

func TestConnectAuthentication(t *testing.T) {
	const procedure = splajompyv1connect.NotificationServiceGetUnreadNotificationCountProcedure
	mux := http.NewServeMux()
	h := handler.NewHandler(nil, []handler.ConnectRegistrar{connectHandler{}})
	h.RegisterConnectRoutes(mux, nil)
	canceled, cancel := context.WithCancel(t.Context())
	cancel()
	expired, cancel := context.WithDeadline(t.Context(), time.Now().Add(-time.Second))
	defer cancel()

	for _, tc := range []struct {
		name, path, authorization, version string
		ctx                                context.Context
		status                             int
		code                               string
	}{
		{name: "missing authorization", path: procedure, status: http.StatusUnauthorized, code: "unauthenticated"},
		{name: "unknown procedure", path: "/splajompy.v1.NotificationService/Unknown", status: http.StatusNotImplemented, code: "unimplemented"},
		{name: "invalid authorization", path: procedure, authorization: "Basic token", status: http.StatusBadRequest, code: "invalid_argument"},
		{name: "old app version", path: procedure, version: "v1.8.0", status: http.StatusBadRequest, code: "failed_precondition"},
		{name: "old app version without prefix", path: procedure, version: "1.8.0", status: http.StatusBadRequest, code: "failed_precondition"},
		{name: "canceled request", path: procedure, ctx: canceled, status: 499, code: "canceled"},
		{name: "expired request", path: procedure, ctx: expired, status: http.StatusGatewayTimeout, code: "deadline_exceeded"},
	} {
		t.Run(tc.name, func(t *testing.T) {
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
			var body struct{ Code string }
			require.NoError(t, json.Unmarshal(response.Body.Bytes(), &body))
			require.Equal(t, tc.code, body.Code)
		})
	}
}

func TestConnectUpgradeErrorDetails(t *testing.T) {
	mux := http.NewServeMux()
	handler.NewHandler(nil, []handler.ConnectRegistrar{connectHandler{}}).RegisterConnectRoutes(mux, nil)
	server := httptest.NewServer(mux)
	t.Cleanup(server.Close)
	client := splajompyv1connect.NewNotificationServiceClient(connect.NewClient(connecthttp.NewTransport(server.Client(), server.URL)))
	ctx, info := connect.NewClientContext(t.Context())
	info.RequestHeader().Set("X-App-Version", "1.8.0")

	_, err := client.GetUnreadNotificationCount(ctx, &splajompyv1.GetUnreadNotificationCountRequest{})
	require.Equal(t, connect.CodeFailedPrecondition, connect.CodeOf(err))
	var rpcError *connect.Error
	require.ErrorAs(t, err, &rpcError)
	require.Len(t, rpcError.Details(), 1)
	detail, err := connectproto.UnmarshalErrorDetail(rpcError.Details()[0])
	require.NoError(t, err)
	errorInfo, ok := detail.(*errdetails.ErrorInfo)
	require.True(t, ok)
	require.Equal(t, "APP_UPGRADE_REQUIRED", errorInfo.GetReason())
	require.Equal(t, "splajompy.com", errorInfo.GetDomain())
	require.Equal(t, middleware.MinimumAppVersion, errorInfo.GetMetadata()["minimumAppVersion"])
}

func TestAuthenticatePreservesRequestSpan(t *testing.T) {
	db := testutil.StartPostgres(t)
	user := testutil.CreateTestUser(t, db.UserRepository, "owner")
	require.NoError(t, db.UserRepository.CreateSession(t.Context(), "owner-token", user.UserID, time.Now().UTC().Add(time.Hour)))
	ctx, span := sdktrace.NewTracerProvider().Tracer("test").Start(t.Context(), "request")
	defer span.End()

	authenticatedCtx, err := middleware.Authenticate(ctx, db.Queries, "Bearer owner-token")
	require.Nil(t, err)
	require.True(t, trace.SpanFromContext(authenticatedCtx).IsRecording())
}

func TestConnectSessionErrors(t *testing.T) {
	db := testutil.StartPostgres(t)
	mux := http.NewServeMux()
	handler.NewHandler(nil, []handler.ConnectRegistrar{connectHandler{}}).RegisterConnectRoutes(mux, db.Queries)
	server := httptest.NewServer(mux)
	t.Cleanup(server.Close)
	client := splajompyv1connect.NewNotificationServiceClient(connect.NewClient(connecthttp.NewTransport(server.Client(), server.URL)))
	ctx, info := connect.NewClientContext(t.Context())
	info.RequestHeader().Set("Authorization", "Bearer invalid")
	request := &splajompyv1.GetUnreadNotificationCountRequest{}

	t.Run("invalid session", func(t *testing.T) {
		_, err := client.GetUnreadNotificationCount(ctx, request)
		require.Equal(t, connect.CodeUnauthenticated, connect.CodeOf(err))
	})

	t.Run("database unavailable", func(t *testing.T) {
		db.Pool.Close()
		_, err := client.GetUnreadNotificationCount(ctx, request)
		require.Equal(t, connect.CodeInternal, connect.CodeOf(err))
	})
}
