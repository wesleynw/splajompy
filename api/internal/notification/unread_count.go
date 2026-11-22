package notification

import (
	"context"
	"errors"
	"fmt"
	"time"
)

const (
	unreadCountStreamDuration    = 5 * time.Minute
	unreadCountHeartbeatInterval = 30 * time.Second
)

var errUnreadCountUnavailable = errors.New("unread notification count unavailable")

type unreadCountChanges interface {
	Subscribe(ctx context.Context, userID int) (<-chan struct{}, func(), error)
}

type UnreadCountWatcher struct {
	store   Store
	changes unreadCountChanges
}

func NewUnreadCountWatcher(store Store, changes unreadCountChanges) *UnreadCountWatcher {
	return &UnreadCountWatcher{store: store, changes: changes}
}

// Watch sends each count from the goroutine that calls it.
func (w *UnreadCountWatcher) Watch(ctx context.Context, userID int, send func(int) error) (err error) {
	parent := ctx
	ctx, cancel := context.WithTimeout(ctx, unreadCountStreamDuration)
	defer cancel()
	defer func() {
		// End normally at our five minute limit. Keep client deadlines and other errors.
		if errors.Is(err, context.DeadlineExceeded) && ctx.Err() == context.DeadlineExceeded && parent.Err() == nil {
			err = nil
		}
	}()
	updates, unsubscribe, err := w.changes.Subscribe(ctx, userID)
	if err != nil {
		return fmt.Errorf("%w: %w", errUnreadCountUnavailable, err)
	}
	defer unsubscribe()

	// Start listening before reading the count so a change during the read is not lost.
	count, err := w.store.GetUserUnreadNotificationCount(ctx, userID)
	if err != nil {
		return fmt.Errorf("%w: %w", errUnreadCountUnavailable, err)
	}
	if err := send(count); err != nil {
		return err
	}
	heartbeat := time.NewTicker(unreadCountHeartbeatInterval)
	defer heartbeat.Stop()
	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-heartbeat.C:
			// Send the last count again. A heartbeat does not need a database read.
		case _, ok := <-updates:
			if !ok {
				return errUnreadCountUnavailable
			}
			current, err := w.store.GetUserUnreadNotificationCount(ctx, userID)
			if err != nil {
				return fmt.Errorf("%w: %w", errUnreadCountUnavailable, err)
			}
			if current == count {
				continue
			}
			count = current
		}
		if err := send(count); err != nil {
			return err
		}
	}
}
