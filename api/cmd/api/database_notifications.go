package main

import (
	"errors"
	"os"

	"github.com/jackc/pgx/v5"
	"splajompy.com/api/v2/internal/pgnotify"
)

func newDatabaseListener(config *pgx.ConnConfig, handlers ...pgnotify.Handler) (*pgnotify.Listener, error) {
	// LISTEN requires a direct or session-pooled connection.
	if url := os.Getenv("DB_LISTEN_CONNECTION_STRING"); url != "" {
		var err error
		config, err = pgx.ParseConfig(url)
		if err != nil {
			return nil, errors.New("invalid DB_LISTEN_CONNECTION_STRING")
		}
	}
	return pgnotify.NewListener(config, handlers...), nil
}
