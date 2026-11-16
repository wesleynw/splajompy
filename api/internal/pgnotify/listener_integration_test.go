package pgnotify_test

import (
	"context"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
	"splajompy.com/api/v2/internal/pgnotify"
	"splajompy.com/api/v2/internal/testutil"
)

func TestListenerPostgresChannels(t *testing.T) {
	db := testutil.StartPostgres(t)
	config := db.Pool.Config().ConnConfig.Copy()
	config.RuntimeParams["application_name"] = t.Name()
	channels := []string{"count changes", `post"changes`}
	listener := pgnotify.NewListener(config, channels...)
	ctx, cancel := context.WithTimeout(t.Context(), 10*time.Second)
	defer cancel()
	for _, channel := range channels {
		changes, unsubscribe, err := listener.Subscribe(ctx, channel, "7")
		require.NoError(t, err)
		t.Cleanup(unsubscribe)
		_, err = db.Pool.Exec(ctx, "SELECT pg_notify($1, $2)", channel, "7")
		require.NoError(t, err)
		select {
		case _, open := <-changes:
			require.True(t, open)
		case <-ctx.Done():
			t.Fatal(ctx.Err())
		}
	}
	var connections int
	err := db.Pool.QueryRow(ctx, "SELECT count(*) FROM pg_stat_activity WHERE application_name = $1", t.Name()).Scan(&connections)
	require.NoError(t, err)
	require.Equal(t, 1, connections)
}
