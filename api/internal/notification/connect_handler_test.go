package notification_test

import (
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
	"splajompy.com/api/v2/internal/server"
	"splajompy.com/api/v2/internal/testutil"
)

func TestGetUnreadNotificationCount(t *testing.T) {
	db := testutil.StartPostgres(t)
	svc := notification.NewService(db.NotificationStore, db.PostRepository, &db.CommentRepository, db.UserRepository, db.BucketRepository, apns.Client{})
	mux := http.NewServeMux()
	server.RegisterREST(mux, db.Queries, notification.NewHandler(svc))
	rpcServer := connect.NewServer(interceptor.AppVersion, interceptor.Auth(db.Queries), validate.NewServerInterceptor())
	splajompyv1connect.RegisterNotificationServiceHandler(rpcServer, notification.NewConnectHandler(svc))
	connecthttp.Mount(mux, rpcServer)
	server := httptest.NewServer(mux)
	t.Cleanup(server.Close)
	client := splajompyv1connect.NewNotificationServiceClient(connect.NewClient(connecthttp.NewTransport(server.Client(), server.URL)))

	owner := testutil.CreateTestUser(t, db.UserRepository, "owner")
	other := testutil.CreateTestUser(t, db.UserRepository, "other")
	require.NoError(t, db.UserRepository.CreateSession(t.Context(), "owner-token", owner.UserID, time.Now().UTC().Add(time.Hour)))
	ctx, info := connect.NewClientContext(t.Context())
	info.RequestHeader().Set("Authorization", "Bearer owner-token")
	request := &splajompyv1.GetUnreadNotificationCountRequest{}

	response, err := client.GetUnreadNotificationCount(ctx, request)
	require.NoError(t, err)
	require.Zero(t, response.GetUnreadCount())

	for _, userID := range []int{owner.UserID, other.UserID} {
		_, err := db.NotificationStore.InsertNotification(ctx, userID, nil, nil, nil, "unread", models.NotificationTypeAnnouncement, nil)
		require.NoError(t, err)
	}

	response, err = client.GetUnreadNotificationCount(ctx, request)
	require.NoError(t, err)
	require.EqualValues(t, 1, response.GetUnreadCount())

	restRequest := httptest.NewRequest(http.MethodPost, "/notifications/markRead", nil)
	restRequest.Header.Set("Authorization", "Bearer owner-token")
	restResponse := httptest.NewRecorder()
	mux.ServeHTTP(restResponse, restRequest)
	require.Equal(t, http.StatusOK, restResponse.Code)

	response, err = client.GetUnreadNotificationCount(ctx, request)
	require.NoError(t, err)
	require.Zero(t, response.GetUnreadCount())
}
