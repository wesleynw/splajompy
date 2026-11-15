package notification

import (
	"context"
	"testing"
	"testing/synctest"
	"time"

	"github.com/stretchr/testify/require"
	"splajompy.com/api/v2/internal/db/queries"
	"splajompy.com/api/v2/internal/models"
)

type blockedCountQueries struct{ queries.Querier }

func (blockedCountQueries) GetUserUnreadNotificationCount(ctx context.Context, _ int) (int64, error) {
	<-ctx.Done()
	return 0, ctx.Err()
}

func TestUnreadCountStreamDeadline(t *testing.T) {
	for _, timeout := range []time.Duration{0, time.Minute} {
		t.Run(timeout.String(), func(t *testing.T) {
			synctest.Test(t, func(t *testing.T) {
				ctx := t.Context()
				if timeout > 0 {
					var cancel context.CancelFunc
					ctx, cancel = context.WithTimeout(ctx, timeout)
					defer cancel()
				}
				svc := &Service{notificationRepository: Store{
					querier: blockedCountQueries{},
					unreadCounts: &unreadCountListener{session: &unreadCountSession{
						cancel: func() {}, subscribers: make(map[int]map[chan struct{}]struct{}),
					}},
				}}
				start := time.Now()
				err := svc.WatchUnreadNotificationCount(ctx, models.PublicUser{}, func(int) error {
					t.Fatal("blocked count query sent a response")
					return nil
				})
				if timeout > 0 {
					require.ErrorIs(t, err, context.DeadlineExceeded)
					require.Equal(t, timeout, time.Since(start))
				} else {
					require.NoError(t, err)
					require.Equal(t, 5*time.Minute, time.Since(start))
				}
			})
		})
	}
}
