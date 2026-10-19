package notification_test

import (
	"net/http"
	"net/http/httptest"
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
	"splajompy.com/api/v2/internal/apns"
	"splajompy.com/api/v2/internal/handler"
	"splajompy.com/api/v2/internal/middleware"
	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/notification"
	"splajompy.com/api/v2/internal/testutil"
)

func TestConnectUnreadCountWithREST(t *testing.T) {
	db := testutil.StartPostgres(t)
	svc := notification.NewService(db.NotificationStore, db.PostRepository, &db.CommentRepository, db.UserRepository, db.BucketRepository, apns.Client{})
	mux := http.NewServeMux()
	h := handler.NewHandler(
		[]handler.RESTRegistrar{notification.NewHandler(svc)},
		[]handler.ConnectRegistrar{notification.NewConnectHandler(svc)},
	)
	h.RegisterRESTRoutes(mux, db.Queries)
	h.RegisterConnectRoutes(mux, db.Queries)
	server := httptest.NewUnstartedServer(mux)
	server.EnableHTTP2 = true
	server.StartTLS()
	t.Cleanup(server.Close)

	owner := testutil.CreateTestUser(t, db.UserRepository, "owner")
	require.NoError(t, db.UserRepository.CreateSession(t.Context(), "owner-token", owner.UserID, time.Now().UTC().Add(time.Hour)))
	requestCtx, span := sdktrace.NewTracerProvider().Tracer("test").Start(t.Context(), "request")
	defer span.End()
	authenticatedCtx, authErr := middleware.Authenticate(requestCtx, db.Queries, "Bearer owner-token")
	require.Nil(t, authErr)
	require.True(t, trace.SpanFromContext(authenticatedCtx).IsRecording())
	transport := connecthttp.NewTransport(server.Client(), server.URL)
	client := splajompyv1connect.NewNotificationServiceClient(connect.NewClient(transport))
	ctx, info := connect.NewClientContext(t.Context())
	info.RequestHeader().Set("Authorization", "Bearer invalid")
	_, err := client.GetUnreadNotificationCount(ctx, &splajompyv1.GetUnreadNotificationCountRequest{})
	require.Equal(t, connect.CodeUnauthenticated, connect.CodeOf(err))

	info.RequestHeader().Set("Authorization", "Bearer owner-token")
	response, err := client.GetUnreadNotificationCount(ctx, &splajompyv1.GetUnreadNotificationCountRequest{})
	require.NoError(t, err)
	require.Zero(t, response.GetUnreadCount())

	other := testutil.CreateTestUser(t, db.UserRepository, "other")
	for _, userID := range []int{owner.UserID, other.UserID} {
		_, err := db.NotificationStore.InsertNotification(t.Context(), userID, nil, nil, nil, "unread", models.NotificationTypeAnnouncement, nil)
		require.NoError(t, err)
	}
	for protocol, option := range map[string]connecthttp.Option{
		"connect":     connecthttp.WithSendCodec("proto"),
		"connectJSON": connecthttp.WithSendCodec("json"),
		"grpc":        connecthttp.WithGRPC(),
		"grpcWeb":     connecthttp.WithGRPCWeb(),
	} {
		t.Run(protocol, func(t *testing.T) {
			transport := connecthttp.NewTransport(server.Client(), server.URL, option)
			client := splajompyv1connect.NewNotificationServiceClient(connect.NewClient(transport))
			ctx, info := connect.NewClientContext(t.Context())
			_, err := client.GetUnreadNotificationCount(ctx, &splajompyv1.GetUnreadNotificationCountRequest{})
			require.Equal(t, connect.CodeUnauthenticated, connect.CodeOf(err))

			info.RequestHeader().Set("Authorization", "Bearer owner-token")
			response, err := client.GetUnreadNotificationCount(ctx, &splajompyv1.GetUnreadNotificationCountRequest{})
			require.NoError(t, err)
			require.EqualValues(t, 1, response.GetUnreadCount())

			info.RequestHeader().Set("X-App-Version", "1.8.0")
			_, err = client.GetUnreadNotificationCount(ctx, &splajompyv1.GetUnreadNotificationCountRequest{})
			require.Equal(t, connect.CodeFailedPrecondition, connect.CodeOf(err))
			var rpcError *connect.Error
			require.ErrorAs(t, err, &rpcError)
			require.Len(t, rpcError.Details(), 1)
			detail, detailErr := connectproto.UnmarshalErrorDetail(rpcError.Details()[0])
			require.NoError(t, detailErr)
			errorInfo, ok := detail.(*errdetails.ErrorInfo)
			require.True(t, ok)
			require.Equal(t, "APP_UPGRADE_REQUIRED", errorInfo.GetReason())
			require.Equal(t, "splajompy.com", errorInfo.GetDomain())
			require.Equal(t, middleware.MinimumAppVersion, errorInfo.GetMetadata()["minimumAppVersion"])
		})
	}

	request := httptest.NewRequest(http.MethodPost, "/notifications/markRead", nil)
	request.Header.Set("Authorization", "Bearer owner-token")
	request.Header.Set("X-App-Version", "1.8.0")
	recorder := httptest.NewRecorder()
	mux.ServeHTTP(recorder, request)
	require.Equal(t, http.StatusUpgradeRequired, recorder.Code)

	request.Header.Del("X-App-Version")
	recorder = httptest.NewRecorder()
	mux.ServeHTTP(recorder, request)
	require.Equal(t, http.StatusOK, recorder.Code)

	response, err = client.GetUnreadNotificationCount(ctx, &splajompyv1.GetUnreadNotificationCountRequest{})
	require.NoError(t, err)
	require.Zero(t, response.GetUnreadCount())

	// Database failures must not sign the client out.
	db.Pool.Close()
	_, err = client.GetUnreadNotificationCount(ctx, &splajompyv1.GetUnreadNotificationCountRequest{})
	require.Equal(t, connect.CodeInternal, connect.CodeOf(err))
	recorder = httptest.NewRecorder()
	mux.ServeHTTP(recorder, request)
	require.Equal(t, http.StatusInternalServerError, recorder.Code)
}
