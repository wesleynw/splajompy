package notification_test

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"connectrpc.com/connect/v2"
	"connectrpc.com/connect/v2/connecthttp"
	"github.com/stretchr/testify/require"
	splajompyv1 "splajompy.com/api/v2/gen/splajompy/v1"
	"splajompy.com/api/v2/gen/splajompy/v1/splajompyv1connect"
	"splajompy.com/api/v2/internal/apns"
	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/notification"
	"splajompy.com/api/v2/internal/pgnotify"
	"splajompy.com/api/v2/internal/server"
	"splajompy.com/api/v2/internal/testutil"
)

type notificationHandlerTestEnv struct {
	db            *testutil.TestDB
	mux           *http.ServeMux
	client        splajompyv1connect.NotificationServiceClient
	ctx           context.Context
	userID        int
	listenerReady <-chan struct{}
}

func setupNotificationHandler(t *testing.T, startListener bool) notificationHandlerTestEnv {
	t.Helper()
	db := testutil.StartPostgres(t)
	svc := notification.NewService(db.NotificationStore, db.PostRepository, &db.CommentRepository, db.UserRepository, db.BucketRepository, apns.Client{})
	changes := new(notification.PostgresUnreadCountChanges)
	watcher := notification.NewUnreadCountWatcher(db.NotificationStore, changes)
	httpServer, mux := server.NewServer()
	server.RegisterREST(mux, db.Queries, notification.NewHandler(svc))
	server.RegisterRPC(mux, db.Queries, notification.NewConnectHandler(svc, watcher))
	testServer := httptest.NewUnstartedServer(httpServer.Handler)
	testServer.EnableHTTP2 = true
	testServer.Config.WriteTimeout = httpServer.WriteTimeout
	testServer.StartTLS()
	t.Cleanup(testServer.Close)
	client := splajompyv1connect.NewNotificationServiceClient(connect.NewClient(connecthttp.NewTransport(testServer.Client(), testServer.URL)))
	owner := testutil.CreateTestUser(t, db.UserRepository, "owner")
	require.NoError(t, db.UserRepository.CreateSession(t.Context(), "owner-token", owner.UserID, time.Now().UTC().Add(time.Hour)))
	ctx, cancel := context.WithTimeout(t.Context(), 10*time.Second)
	t.Cleanup(cancel)
	ctx, info := connect.NewClientContext(ctx)
	info.RequestHeader().Set("Authorization", "Bearer owner-token")
	env := notificationHandlerTestEnv{db: db, mux: mux, client: client, ctx: ctx, userID: owner.UserID}
	if startListener {
		env.listenerReady = runNotificationListener(t, db, changes)
		env.waitForListener(t)
	}
	return env
}

func runNotificationListener(t *testing.T, db *testutil.TestDB, changes *notification.PostgresUnreadCountChanges) <-chan struct{} {
	t.Helper()
	ready := make(chan struct{}, 1)
	handler := changes.Handler()
	setAvailable := handler.SetAvailable
	handler.SetAvailable = func(available bool) {
		setAvailable(available)
		if available {
			select {
			case ready <- struct{}{}:
			default:
			}
		}
	}
	listener := pgnotify.NewListener(db.Pool.Config().ConnConfig, handler)
	ctx, cancel := context.WithCancel(t.Context())
	done := make(chan struct{})
	go func() {
		defer close(done)
		listener.Run(ctx)
	}()
	t.Cleanup(func() {
		cancel()
		<-done
	})
	return ready
}

func (env notificationHandlerTestEnv) waitForListener(t *testing.T) {
	t.Helper()
	select {
	case <-env.listenerReady:
	case <-env.ctx.Done():
		t.Fatal("PostgreSQL listener did not become ready")
	}
}

func TestGetUnreadNotificationCount(t *testing.T) {
	env := setupNotificationHandler(t, false)
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
	env := setupNotificationHandler(t, true)
	stream, err := env.client.WatchUnreadNotificationCount(env.ctx, &splajompyv1.WatchUnreadNotificationCountRequest{})
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, stream.Close()) })

	requireStreamCount(t, stream, 0)
	// Each concurrent call needs its own request headers.
	secondCtx, secondInfo := connect.NewClientContext(env.ctx)
	secondInfo.RequestHeader().Set("Authorization", "Bearer owner-token")
	secondCtx, stopSecond := context.WithCancel(secondCtx)
	defer stopSecond()
	second, err := env.client.WatchUnreadNotificationCount(secondCtx, &splajompyv1.WatchUnreadNotificationCountRequest{})
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, second.Close()) })
	requireStreamCount(t, second, 0)
	_, err = env.db.NotificationStore.InsertNotification(env.ctx, env.userID, nil, nil, nil, "unread", models.NotificationTypeAnnouncement, nil)
	require.NoError(t, err)
	requireStreamCount(t, stream, 1)
	requireStreamCount(t, second, 1)
	stopSecond()
	_, err = second.Receive()
	require.Equal(t, connect.CodeCanceled, connect.CodeOf(err))

	request := httptest.NewRequest(http.MethodPost, "/notifications/markRead", nil)
	request.Header.Set("Authorization", "Bearer owner-token")
	recorder := httptest.NewRecorder()
	env.mux.ServeHTTP(recorder, request)
	require.Equal(t, http.StatusOK, recorder.Code)
	requireStreamCount(t, stream, 0)

	notification, err := env.db.NotificationStore.InsertNotification(env.ctx, env.userID, nil, nil, nil, "unread", models.NotificationTypeAnnouncement, nil)
	require.NoError(t, err)
	requireStreamCount(t, stream, 1)
	require.NoError(t, env.db.NotificationStore.DeleteNotificationById(env.ctx, notification.NotificationID))
	requireStreamCount(t, stream, 0)
}

func TestWatchUnreadNotificationCountReconnect(t *testing.T) {
	env := setupNotificationHandler(t, true)
	stream, err := env.client.WatchUnreadNotificationCount(env.ctx, &splajompyv1.WatchUnreadNotificationCountRequest{})
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, stream.Close()) })
	requireStreamCount(t, stream, 0)

	result, err := env.db.Pool.Exec(env.ctx, "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE query LIKE 'LISTEN %'")
	require.NoError(t, err)
	require.EqualValues(t, 1, result.RowsAffected())
	_, err = stream.Receive()
	require.Equal(t, connect.CodeUnavailable, connect.CodeOf(err))
	_, err = env.db.NotificationStore.InsertNotification(env.ctx, env.userID, nil, nil, nil, "unread", models.NotificationTypeAnnouncement, nil)
	require.NoError(t, err)
	env.waitForListener(t)
	reconnected, err := env.client.WatchUnreadNotificationCount(env.ctx, &splajompyv1.WatchUnreadNotificationCountRequest{})
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, reconnected.Close()) })
	requireStreamCount(t, reconnected, 1)
	_, err = env.db.NotificationStore.InsertNotification(env.ctx, env.userID, nil, nil, nil, "unread", models.NotificationTypeAnnouncement, nil)
	require.NoError(t, err)
	requireStreamCount(t, reconnected, 2)
}

func requireStreamCount(t *testing.T, stream splajompyv1connect.NotificationServiceWatchUnreadNotificationCountClientStream, want int64) {
	t.Helper()
	response, err := stream.Receive()
	require.NoError(t, err)
	require.Equal(t, want, response.GetUnreadCount())
}
