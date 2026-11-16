package pgnotify

import (
	"context"
	"fmt"
	"log/slog"
	"slices"
	"sync"
	"time"

	"github.com/jackc/pgx/v5"
)

const (
	connectTimeout = 5 * time.Second
	closeTimeout   = 5 * time.Second
	// Subscribers reload state, so multiple pending changes can share one signal.
	changeBufferSize = 1
)

// Listener shares one PostgreSQL connection across state change subscriptions.
// Signals can coalesce. Consumers must reload state rather than count events.
type Listener struct {
	config   *pgx.ConnConfig
	channels []string
	mu       sync.Mutex
	session  *listenerSession
}

type subscriptionKey struct {
	channel string
	payload string
}

type listenerSession struct {
	conn        *pgx.Conn
	cancel      context.CancelFunc
	subscribers map[subscriptionKey]map[chan struct{}]struct{}
}

// NewListener fixes the channel list before any connection starts receiving.
func NewListener(config *pgx.ConnConfig, channels ...string) *Listener {
	return &Listener{config: config.Copy(), channels: slices.Clone(channels)}
}

// Subscribe returns a private signal channel for the given channel and payload.
// The caller must defer unsubscribe. A closed channel requires a new subscription.
func (l *Listener) Subscribe(ctx context.Context, channel, payload string) (<-chan struct{}, func(), error) {
	if !slices.Contains(l.channels, channel) {
		return nil, nil, fmt.Errorf("unregistered PostgreSQL notification channel %q", channel)
	}
	l.mu.Lock()
	defer l.mu.Unlock()
	if err := ctx.Err(); err != nil {
		return nil, nil, err
	}
	session := l.session
	if session == nil {
		connectCtx, cancel := context.WithTimeout(ctx, connectTimeout)
		defer cancel()
		conn, err := pgx.ConnectConfig(connectCtx, l.config.Copy())
		if err != nil {
			return nil, nil, err
		}
		for _, channel := range l.channels {
			if _, err := conn.Exec(connectCtx, "LISTEN "+pgx.Identifier{channel}.Sanitize()); err != nil {
				_ = conn.Close(connectCtx)
				return nil, nil, err
			}
		}
		// The shared connection lives until its last subscriber leaves.
		listenCtx, stop := context.WithCancel(context.Background())
		session = &listenerSession{conn: conn, cancel: stop, subscribers: make(map[subscriptionKey]map[chan struct{}]struct{})}
		l.session = session
		go l.listen(listenCtx, session)
	}
	key := subscriptionKey{channel: channel, payload: payload}
	changes := make(chan struct{}, changeBufferSize)
	if session.subscribers[key] == nil {
		session.subscribers[key] = make(map[chan struct{}]struct{})
	}
	session.subscribers[key][changes] = struct{}{}
	unsubscribe := func() {
		l.mu.Lock()
		defer l.mu.Unlock()
		subscribers := session.subscribers[key]
		if _, ok := subscribers[changes]; !ok {
			return
		}
		delete(subscribers, changes)
		close(changes)
		if len(subscribers) == 0 {
			delete(session.subscribers, key)
		}
		if len(session.subscribers) == 0 {
			if l.session == session {
				l.session = nil
			}
			session.cancel()
		}
	}
	return changes, unsubscribe, nil
}

func (l *Listener) listen(ctx context.Context, session *listenerSession) {
	defer func() {
		l.mu.Lock()
		if l.session == session {
			l.session = nil
		}
		for _, subscribers := range session.subscribers {
			for changes := range subscribers {
				close(changes)
			}
		}
		clear(session.subscribers)
		l.mu.Unlock()
		session.cancel()
		closeCtx, cancel := context.WithTimeout(context.Background(), closeTimeout)
		defer cancel()
		_ = session.conn.Close(closeCtx)
	}()
	for {
		event, err := session.conn.WaitForNotification(ctx)
		if err != nil {
			if ctx.Err() == nil {
				slog.ErrorContext(ctx, "PostgreSQL notification listener stopped", "error", err)
			}
			return
		}
		l.notify(session, event.Channel, event.Payload)
	}
}

func (l *Listener) notify(session *listenerSession, channel, payload string) {
	// Sending and closing must hold the same lock.
	l.mu.Lock()
	defer l.mu.Unlock()
	for changes := range session.subscribers[subscriptionKey{channel: channel, payload: payload}] {
		select {
		case changes <- struct{}{}:
		default:
		}
	}
}
