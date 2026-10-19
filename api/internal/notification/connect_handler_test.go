package notification_test

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"connectrpc.com/connect/v2"
	"connectrpc.com/connect/v2/connecthttp"
	"connectrpc.com/validate"
	"github.com/stretchr/testify/require"
	splajompyv1 "splajompy.com/api/v2/gen/splajompy/v1"
	"splajompy.com/api/v2/gen/splajompy/v1/splajompyv1connect"
	"splajompy.com/api/v2/internal/apns"
	"splajompy.com/api/v2/internal/interceptor"
	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/notification"
	"splajompy.com/api/v2/internal/routes"
	"splajompy.com/api/v2/internal/testutil"
)

type notificationHandlerTestEnv struct {
	db     *testutil.TestDB
	mux    *http.ServeMux
	client splajompyv1connect.NotificationServiceClient
	ctx    context.Context
	userID int
}

func setupNotificationHandler(t *testing.T) notificationHandlerTestEnv {
	t.Helper()
	db := testutil.StartPostgres(t)
	svc := notification.NewService(db.NotificationStore, db.PostRepository, &db.CommentRepository, db.UserRepository, db.BucketRepository, apns.Client{})
	mux := http.NewServeMux()
	routes.RegisterREST(mux, db.Queries, notification.NewHandler(svc))
	rpcServer := connect.NewServer(interceptor.AppVersion, interceptor.Auth(db.Queries), validate.NewServerInterceptor())
	splajompyv1connect.RegisterNotificationServiceHandler(rpcServer, notification.NewConnectHandler(svc))
	connecthttp.Mount(mux, rpcServer)
	server := httptest.NewUnstartedServer(mux)
	server.EnableHTTP2 = true
	server.StartTLS()
	t.Cleanup(server.Close)
	client := splajompyv1connect.NewNotificationServiceClient(connect.NewClient(connecthttp.NewTransport(server.Client(), server.URL)))
	owner := testutil.CreateTestUser(t, db.UserRepository, "owner")
	require.NoError(t, db.UserRepository.CreateSession(t.Context(), "owner-token", owner.UserID, time.Now().UTC().Add(time.Hour)))
	ctx, info := connect.NewClientContext(t.Context())
	info.RequestHeader().Set("Authorization", "Bearer owner-token")
	return notificationHandlerTestEnv{db: db, mux: mux, client: client, ctx: ctx, userID: owner.UserID}
}

func TestGetUnreadNotificationCount(t *testing.T) {
	env := setupNotificationHandler(t)
	request := &splajompyv1.GetUnreadNotificationCountRequest{}
	response, err := env.client.GetUnreadNotificationCount(env.ctx, request)
	require.NoError(t, err)
	require.Zero(t, response.GetUnreadCount())

	other := testutil.CreateTestUser(t, env.db.UserRepository, "other")
	for _, userID := range []int{env.userID, other.UserID} {
		_, err := env.db.NotificationStore.InsertNotification(env.ctx, userID, nil, nil, nil, "unread", models.NotificationTypeAnnouncement, nil)
		require.NoError(t, err)
	}
	response, err = env.client.GetUnreadNotificationCount(env.ctx, request)
	require.NoError(t, err)
	require.EqualValues(t, 1, response.GetUnreadCount())
}

func TestWatchUnreadNotificationCount(t *testing.T) {
	env := setupNotificationHandler(t)
	ctx, cancel := context.WithTimeout(env.ctx, 10*time.Second)
	defer cancel()
	stream, err := env.client.WatchUnreadNotificationCount(ctx, &splajompyv1.WatchUnreadNotificationCountRequest{})
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, stream.Close()) })

	response, err := stream.Receive()
	require.NoError(t, err)
	require.Zero(t, response.GetUnreadCount())
	other := testutil.CreateTestUser(t, env.db.UserRepository, "other")
	for _, userID := range []int{other.UserID, env.userID} {
		_, err := env.db.NotificationStore.InsertNotification(ctx, userID, nil, nil, nil, "unread", models.NotificationTypeAnnouncement, nil)
		require.NoError(t, err)
	}
	response, err = stream.Receive()
	require.NoError(t, err)
	require.EqualValues(t, 1, response.GetUnreadCount())

	request := httptest.NewRequest(http.MethodPost, "/notifications/markRead", nil)
	request.Header.Set("Authorization", "Bearer owner-token")
	recorder := httptest.NewRecorder()
	env.mux.ServeHTTP(recorder, request)
	require.Equal(t, http.StatusOK, recorder.Code)
	response, err = stream.Receive()
	require.NoError(t, err)
	require.Zero(t, response.GetUnreadCount())

	notification, err := env.db.NotificationStore.InsertNotification(ctx, env.userID, nil, nil, nil, "unread", models.NotificationTypeAnnouncement, nil)
	require.NoError(t, err)
	response, err = stream.Receive()
	require.NoError(t, err)
	require.EqualValues(t, 1, response.GetUnreadCount())
	require.NoError(t, env.db.NotificationStore.DeleteNotificationById(ctx, notification.NotificationID))
	response, err = stream.Receive()
	require.NoError(t, err)
	require.Zero(t, response.GetUnreadCount())

	cancel()
	_, err = stream.Receive()
	require.Equal(t, connect.CodeCanceled, connect.CodeOf(err))
}
