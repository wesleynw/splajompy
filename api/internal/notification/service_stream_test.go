package notification

import (
	"context"
	"errors"
	"testing"
	"testing/synctest"
	"time"

	"github.com/stretchr/testify/require"
	"splajompy.com/api/v2/internal/db/queries"
)

type countQueries struct {
	queries.Querier
	count func(context.Context) (int64, error)
}

func (q countQueries) GetUserUnreadNotificationCount(ctx context.Context, _ int) (int64, error) {
	return q.count(ctx)
}

type countChanges chan struct{}

func (changes countChanges) Subscribe(context.Context, int) (<-chan struct{}, func(), error) {
	return changes, func() {}, nil
}

func TestUnreadCountStreamDeadline(t *testing.T) {
	queryFailure := errors.New("query failed")
	for _, test := range []struct {
		name     string
		timeout  time.Duration
		queryErr error
		wantErr  error
		elapsed  time.Duration
	}{
		{name: "stream expires", timeout: time.Hour, elapsed: 5 * time.Minute},
		{name: "client deadline", timeout: time.Minute, wantErr: context.DeadlineExceeded, elapsed: time.Minute},
		{name: "query failure at expiry", timeout: time.Hour, queryErr: queryFailure, wantErr: queryFailure, elapsed: 5 * time.Minute},
	} {
		t.Run(test.name, func(t *testing.T) {
			// The test clock advances to the deadline without a real wait.
			synctest.Test(t, func(t *testing.T) {
				ctx, cancel := context.WithTimeout(t.Context(), test.timeout)
				defer cancel()
				watcher := NewUnreadCountWatcher(Store{
					querier: countQueries{count: func(ctx context.Context) (int64, error) {
						<-ctx.Done()
						if test.queryErr != nil {
							return 0, test.queryErr
						}
						return 0, ctx.Err()
					}},
				}, make(countChanges))
				start := time.Now()
				err := watcher.Watch(ctx, 7, func(int) error {
					t.Fatal("blocked count query sent a response")
					return nil
				})
				require.ErrorIs(t, err, test.wantErr)
				require.Equal(t, test.elapsed, time.Since(start))
			})
		})
	}
}

func TestUnreadCountStreamHeartbeat(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		ctx, cancel := context.WithCancel(t.Context())
		defer cancel()
		queryCount := 0
		changes := make(countChanges, 1)
		watcher := NewUnreadCountWatcher(Store{
			querier: countQueries{count: func(context.Context) (int64, error) {
				queryCount++
				return 1, nil
			}},
		}, changes)
		counts := make(chan int, 2)
		done := make(chan error, 1)
		go func() {
			done <- watcher.Watch(ctx, 7, func(count int) error {
				counts <- count
				return nil
			})
		}()
		synctest.Wait()
		require.Equal(t, 1, <-counts)
		changes <- struct{}{}
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
