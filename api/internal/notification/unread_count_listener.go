package notification

import (
	"context"
	"log/slog"
	"strconv"
	"sync"
	"time"

	"github.com/jackc/pgx/v5"
)

type unreadCountListener struct {
	config  *pgx.ConnConfig
	mu      sync.Mutex
	session *unreadCountSession
}

type unreadCountSession struct {
	conn        *pgx.Conn
	cancel      context.CancelFunc
	subscribers map[int]map[chan struct{}]struct{}
}

func (l *unreadCountListener) subscribe(ctx context.Context, userID int) (<-chan struct{}, func(), error) {
	l.mu.Lock()
	defer l.mu.Unlock()
	session := l.session
	if session == nil {
		connectCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
		defer cancel()
		conn, err := pgx.ConnectConfig(connectCtx, l.config.Copy())
		if err != nil {
			return nil, nil, err
		}
		if _, err := conn.Exec(connectCtx, "LISTEN notification_unread_count_changed"); err != nil {
			_ = conn.Close(connectCtx)
			return nil, nil, err
		}
		// The shared listener lives until its last subscriber leaves.
		listenCtx, stop := context.WithCancel(context.Background())
		session = &unreadCountSession{conn: conn, cancel: stop, subscribers: make(map[int]map[chan struct{}]struct{})}
		l.session = session
		go l.listen(listenCtx, session)
	}
	updates := make(chan struct{}, 1)
	if session.subscribers[userID] == nil {
		session.subscribers[userID] = make(map[chan struct{}]struct{})
	}
	session.subscribers[userID][updates] = struct{}{}
	unsubscribe := func() {
		l.mu.Lock()
		defer l.mu.Unlock()
		delete(session.subscribers[userID], updates)
		if len(session.subscribers[userID]) == 0 {
			delete(session.subscribers, userID)
		}
		if len(session.subscribers) == 0 {
			if l.session == session {
				l.session = nil
			}
			session.cancel()
		}
	}
	return updates, unsubscribe, nil
}

func (l *unreadCountListener) listen(ctx context.Context, session *unreadCountSession) {
	defer func() {
		closeCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		_ = session.conn.Close(closeCtx)
		l.mu.Lock()
		defer l.mu.Unlock()
		if l.session == session {
			l.session = nil
		}
		for _, subscribers := range session.subscribers {
			for updates := range subscribers {
				close(updates)
			}
		}
		clear(session.subscribers)
	}()
	for {
		event, err := session.conn.WaitForNotification(ctx)
		if err != nil {
			if ctx.Err() == nil {
				slog.ErrorContext(ctx, "notification count listener stopped", "error", err)
			}
			return
		}
		userID, err := strconv.Atoi(event.Payload)
		if err != nil {
			continue
		}
		l.mu.Lock()
		for updates := range session.subscribers[userID] {
			select {
			case updates <- struct{}{}:
			default:
			}
		}
		l.mu.Unlock()
	}
}
