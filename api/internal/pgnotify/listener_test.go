package pgnotify

import (
	"strconv"
	"sync"
	"testing"

	"github.com/jackc/pgx/v5/pgconn"
	"github.com/stretchr/testify/require"
	"splajompy.com/api/v2/internal/signals"
)

func TestListenerDispatch(t *testing.T) {
	var first, second signals.Group[int]
	var payloads []string
	listener := &Listener{handlers: map[string][]Handler{
		"counts": {
			{
				Notify: func(event *pgconn.Notification) {
					key, err := strconv.Atoi(event.Payload)
					require.NoError(t, err)
					first.Signal(key)
				},
				SetAvailable: first.SetAvailable,
			},
			{Notify: func(event *pgconn.Notification) { payloads = append(payloads, event.Payload) }},
		},
		"posts": {{SetAvailable: second.SetAvailable, Notify: func(*pgconn.Notification) { second.Signal(7) }}},
	}}
	_, _, err := first.Subscribe(t.Context(), 7)
	require.ErrorIs(t, err, signals.ErrUnavailable)
	listener.setAvailable(true)
	phone, stopPhone, err := first.Subscribe(t.Context(), 7)
	require.NoError(t, err)
	defer stopPhone()
	tablet, stopTablet, err := first.Subscribe(t.Context(), 7)
	require.NoError(t, err)
	defer stopTablet()
	other, stopOther, err := first.Subscribe(t.Context(), 8)
	require.NoError(t, err)
	defer stopOther()
	posts, stopPosts, err := second.Subscribe(t.Context(), 7)
	require.NoError(t, err)
	defer stopPosts()

	for range 2 {
		listener.notify(&pgconn.Notification{Channel: "counts", Payload: "7"})
	}
	require.Equal(t, []string{"7", "7"}, payloads)
	require.Len(t, phone, 1)
	require.Len(t, tablet, 1)
	require.Empty(t, other)
	require.Empty(t, posts)

	listener.setAvailable(false)
	_, open := <-other
	require.False(t, open)
	listener.setAvailable(true)
	restored, stopRestored, err := first.Subscribe(t.Context(), 7)
	require.NoError(t, err)
	defer stopRestored()
	stopPhone()
	listener.notify(&pgconn.Notification{Channel: "counts", Payload: "7"})
	require.Len(t, restored, 1)
}

func TestSignalGroupConcurrentSubscriptions(t *testing.T) {
	var group signals.Group[int]
	group.SetAvailable(true)
	var workers sync.WaitGroup
	for range 100 {
		workers.Go(func() {
			_, stop, err := group.Subscribe(t.Context(), 7)
			if err != nil {
				t.Error(err)
				return
			}
			group.Signal(7)
			stop()
		})
	}
	workers.Wait()
}
