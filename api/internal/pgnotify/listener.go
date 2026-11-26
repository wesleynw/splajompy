package pgnotify

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
)

const (
	connectTimeout = 5 * time.Second
	closeTimeout   = 5 * time.Second
	minRetryDelay  = time.Second
	maxRetryDelay  = 30 * time.Second
)

// Handler receives notifications for one PostgreSQL channel.
// Callbacks run on the listener goroutine and must not wait on I/O.
type Handler struct {
	Channel      string
	Notify       func(*pgconn.Notification)
	SetAvailable func(bool)
}

type Listener struct {
	config   *pgx.ConnConfig
	handlers map[string][]Handler
}

func NewListener(config *pgx.ConnConfig, handlers ...Handler) *Listener {
	byChannel := make(map[string][]Handler)
	for _, handler := range handlers {
		byChannel[handler.Channel] = append(byChannel[handler.Channel], handler)
	}
	return &Listener{config: config.Copy(), handlers: byChannel}
}

// Run listens on one dedicated connection and retries until ctx is canceled.
// Run must be called only once at a time.
func (l *Listener) Run(ctx context.Context) {
	delay := minRetryDelay
	for ctx.Err() == nil {
		connected, err := l.listen(ctx)
		if ctx.Err() != nil {
			return
		}
		slog.WarnContext(ctx, "PostgreSQL notification listener stopped", "error", err)
		if connected {
			delay = minRetryDelay
		}
		timer := time.NewTimer(delay)
		select {
		case <-ctx.Done():
			timer.Stop()
			return
		case <-timer.C:
		}
		delay = min(2*delay, maxRetryDelay)
	}
}

func (l *Listener) listen(ctx context.Context) (bool, error) {
	connectCtx, cancel := context.WithTimeout(ctx, connectTimeout)
	defer cancel()
	conn, err := pgx.ConnectConfig(connectCtx, l.config.Copy())
	if err != nil {
		return false, err
	}
	defer func() {
		closeCtx, cancel := context.WithTimeout(context.WithoutCancel(ctx), closeTimeout)
		defer cancel()
		_ = conn.Close(closeCtx)
	}()
	for channel := range l.handlers {
		if _, err := conn.Exec(connectCtx, "LISTEN "+pgx.Identifier{channel}.Sanitize()); err != nil {
			return false, fmt.Errorf("listen on %q: %w", channel, err)
		}
	}
	cancel()
	l.setAvailable(true)
	defer l.setAvailable(false)
	for {
		event, err := conn.WaitForNotification(ctx)
		if err != nil {
			return true, err
		}
		l.notify(event)
	}
}

func (l *Listener) notify(event *pgconn.Notification) {
	for _, handler := range l.handlers[event.Channel] {
		handler.Notify(event)
	}
}

func (l *Listener) setAvailable(available bool) {
	for _, handlers := range l.handlers {
		for _, handler := range handlers {
			if handler.SetAvailable != nil {
				handler.SetAvailable(available)
			}
		}
	}
}
