package notification

import (
	"context"
	"strconv"

	"github.com/jackc/pgx/v5/pgconn"
	"splajompy.com/api/v2/internal/pgnotify"
	"splajompy.com/api/v2/internal/signals"
)

const unreadCountChangedChannel = "notification_unread_count_changed"

type PostgresUnreadCountChanges struct {
	signals signals.Group[int]
}

func (c *PostgresUnreadCountChanges) Subscribe(ctx context.Context, userID int) (<-chan struct{}, func(), error) {
	return c.signals.Subscribe(ctx, userID)
}

func (c *PostgresUnreadCountChanges) Handler() pgnotify.Handler {
	return pgnotify.Handler{
		Channel:      unreadCountChangedChannel,
		Notify:       c.notify,
		SetAvailable: c.signals.SetAvailable,
	}
}

func (c *PostgresUnreadCountChanges) notify(event *pgconn.Notification) {
	userID, err := strconv.Atoi(event.Payload)
	if err == nil {
		c.signals.Signal(userID)
	}
}
