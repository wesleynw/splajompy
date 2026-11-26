package signals

import (
	"context"
	"errors"
	"sync"
)

var ErrUnavailable = errors.New("signal source unavailable")

const pendingSignals = 1

// Group delivers change signals by key. A pending signal covers repeated changes.
// The zero value is unavailable until the source calls SetAvailable(true).
type Group[K comparable] struct {
	mu          sync.Mutex
	available   bool
	subscribers map[K]map[chan struct{}]struct{}
}

// Subscribe registers one receiver. Call the returned function to remove it.
func (g *Group[K]) Subscribe(ctx context.Context, key K) (<-chan struct{}, func(), error) {
	g.mu.Lock()
	defer g.mu.Unlock()
	if err := ctx.Err(); err != nil {
		return nil, nil, err
	}
	if !g.available {
		return nil, nil, ErrUnavailable
	}
	if g.subscribers == nil {
		g.subscribers = make(map[K]map[chan struct{}]struct{})
	}
	if g.subscribers[key] == nil {
		g.subscribers[key] = make(map[chan struct{}]struct{})
	}
	updates := make(chan struct{}, pendingSignals)
	g.subscribers[key][updates] = struct{}{}
	return updates, func() {
		g.mu.Lock()
		defer g.mu.Unlock()
		subscribers := g.subscribers[key]
		if _, ok := subscribers[updates]; !ok {
			return
		}
		delete(subscribers, updates)
		close(updates)
		if len(subscribers) == 0 {
			delete(g.subscribers, key)
		}
	}, nil
}

func (g *Group[K]) Signal(key K) {
	// Use the same lock as removal so a send cannot race with close.
	g.mu.Lock()
	defer g.mu.Unlock()
	for updates := range g.subscribers[key] {
		select {
		case updates <- struct{}{}:
		default:
		}
	}
}

// SetAvailable closes all subscriptions when the source becomes unavailable.
func (g *Group[K]) SetAvailable(available bool) {
	g.mu.Lock()
	defer g.mu.Unlock()
	g.available = available
	if available {
		return
	}
	for _, subscribers := range g.subscribers {
		for updates := range subscribers {
			close(updates)
		}
	}
	clear(g.subscribers)
}
