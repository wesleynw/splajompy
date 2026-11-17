package pgnotify

import (
	"context"
	"sync"
	"testing"

	"github.com/stretchr/testify/require"
)

func testListener(channels ...string) (*Listener, *listenerSession) {
	session := &listenerSession{cancel: func() {}, subscribers: make(map[subscriptionKey]map[chan struct{}]struct{})}
	return &Listener{channels: channels, session: session}, session
}

func TestListenerFanout(t *testing.T) {
	listener, session := testListener("counts", "posts")
	tests := []struct {
		channel string
		payload string
		want    int
		changes <-chan struct{}
	}{
		{channel: "counts", payload: "7", want: 1},
		{channel: "counts", payload: "7", want: 1},
		{channel: "counts", payload: "8"},
		{channel: "posts", payload: "7"},
	}
	for i, test := range tests {
		changes, unsubscribe, err := listener.Subscribe(t.Context(), test.channel, test.payload)
		require.NoError(t, err)
		t.Cleanup(unsubscribe)
		tests[i].changes = changes
	}
	listener.notify(session, "counts", "7")
	listener.notify(session, "counts", "7")
	for _, test := range tests {
		require.Len(t, test.changes, test.want, "channel %s, payload %s", test.channel, test.payload)
	}
}

func TestListenerConcurrentSubscriptions(t *testing.T) {
	listener, session := testListener("counts")
	ctx, cancel := context.WithCancel(t.Context())
	session.cancel = cancel
	_, unsubscribe, err := listener.Subscribe(t.Context(), "counts", "7")
	require.NoError(t, err)
	t.Cleanup(unsubscribe)
	var workers sync.WaitGroup
	for range 100 {
		workers.Go(func() {
			_, stop, err := listener.Subscribe(t.Context(), "counts", "7")
			if err != nil {
				t.Error(err)
				return
			}
			listener.notify(session, "counts", "7")
			stop()
		})
	}
	workers.Wait()
	require.Len(t, session.subscribers[subscriptionKey{channel: "counts", payload: "7"}], 1)
	require.NoError(t, ctx.Err())
	unsubscribe()
	require.ErrorIs(t, ctx.Err(), context.Canceled)
	require.Nil(t, listener.session)
	require.Empty(t, session.subscribers)
}

func TestListenerUnsubscribeOldSession(t *testing.T) {
	listener, _ := testListener("counts")
	oldChanges, stopOld, err := listener.Subscribe(t.Context(), "counts", "7")
	require.NoError(t, err)
	_, replacement := testListener("counts")
	listener.session = replacement
	changes, unsubscribe, err := listener.Subscribe(t.Context(), "counts", "7")
	require.NoError(t, err)
	t.Cleanup(unsubscribe)
	stopOld()
	stopOld()
	_, open := <-oldChanges
	require.False(t, open)
	require.Same(t, replacement, listener.session)
	listener.notify(replacement, "counts", "7")
	require.Len(t, changes, 1)
}
