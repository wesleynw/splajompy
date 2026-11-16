package notification

import (
	"context"
	"errors"
	"testing"
	"testing/synctest"
	"time"

	"github.com/stretchr/testify/require"
	"splajompy.com/api/v2/internal/db/queries"
	"splajompy.com/api/v2/internal/models"
)

type countQueries struct {
	queries.Querier
	count func(context.Context) (int64, error)
}

func (q countQueries) GetUserUnreadNotificationCount(ctx context.Context, _ int) (int64, error) {
	return q.count(ctx)
}

func TestUnreadCountStreamDeadline(t *testing.T) {
	for _, test := range []struct {
		name    string
		timeout time.Duration
		err     error
	}{
		{name: "rotation"},
		{name: "client deadline", timeout: time.Minute},
		{name: "query failure at rotation", err: errors.New("query failed")},
	} {
		t.Run(test.name, func(t *testing.T) {
			synctest.Test(t, func(t *testing.T) {
				ctx := t.Context()
				if test.timeout > 0 {
					var cancel context.CancelFunc
					ctx, cancel = context.WithTimeout(ctx, test.timeout)
					defer cancel()
				}
				svc := &Service{notificationRepository: Store{
					querier: countQueries{count: func(ctx context.Context) (int64, error) {
						<-ctx.Done()
						if test.err != nil {
							return 0, test.err
						}
						return 0, ctx.Err()
					}},
					unreadCounts: &unreadCountListener{session: &unreadCountSession{
						cancel: func() {}, subscribers: make(map[int]map[chan struct{}]struct{}),
					}},
				}}
				start := time.Now()
				err := svc.WatchUnreadNotificationCount(ctx, models.PublicUser{}, func(int) error {
					t.Fatal("blocked count query sent a response")
					return nil
				})
				if test.err != nil {
					require.ErrorIs(t, err, test.err)
					require.Equal(t, 5*time.Minute, time.Since(start))
				} else if test.timeout > 0 {
					require.ErrorIs(t, err, context.DeadlineExceeded)
					require.Equal(t, test.timeout, time.Since(start))
				} else {
					require.NoError(t, err)
					require.Equal(t, 5*time.Minute, time.Since(start))
				}
			})
		})
	}
}

func TestUnreadCountStreamHeartbeat(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		ctx, cancel := context.WithCancel(t.Context())
		defer cancel()
		queryCount := 0
		session := &unreadCountSession{cancel: func() {}, subscribers: make(map[int]map[chan struct{}]struct{})}
		svc := &Service{notificationRepository: Store{
			querier: countQueries{count: func(context.Context) (int64, error) {
				queryCount++
				return 1, nil
			}},
			unreadCounts: &unreadCountListener{session: session},
		}}
		counts := make(chan int, 2)
		done := make(chan error, 1)
		go func() {
			done <- svc.WatchUnreadNotificationCount(ctx, models.PublicUser{}, func(count int) error {
				counts <- count
				return nil
			})
		}()
		synctest.Wait()
		require.Equal(t, 1, <-counts)
		for updates := range session.subscribers[0] {
			updates <- struct{}{}
		}
		synctest.Wait()
		require.Empty(t, counts)
		require.Equal(t, 2, queryCount)
		time.Sleep(30 * time.Second)
		synctest.Wait()
		require.Equal(t, 1, <-counts)
		require.Equal(t, 2, queryCount)
		cancel()
		require.ErrorIs(t, <-done, context.Canceled)
	})
}
