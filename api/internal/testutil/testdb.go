// Package testutil provides helpers for integration tests that need a real PostgreSQL database.
package testutil

import (
	"context"
	"os"
	"path/filepath"
	"runtime"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/testcontainers/testcontainers-go"
	"github.com/testcontainers/testcontainers-go/modules/postgres"
	"github.com/testcontainers/testcontainers-go/wait"
	"splajompy.com/api/v2/internal/db/queries"
)

// TestDB holds the database connection and container for an integration test.
type TestDB struct {
	Pool    *pgxpool.Pool
	Queries *queries.Queries
}

// StartPostgres starts a PostgreSQL container, applies schema.sql, and returns a connected TestDB.
// The container is terminated when the test finishes.
func StartPostgres(t *testing.T) *TestDB {
	t.Helper()
	ctx := context.Background()

	container, err := postgres.Run(ctx, "postgres:17",
		postgres.WithDatabase("testdb"),
		postgres.WithUsername("test"),
		postgres.WithPassword("test"),
		testcontainers.WithWaitStrategy(
			wait.ForLog("database system is ready to accept connections").
				WithOccurrence(2).
				WithStartupTimeout(30*time.Second),
		),
	)
	if err != nil {
		t.Fatalf("failed to start postgres container: %v", err)
	}
	t.Cleanup(func() {
		if err := container.Terminate(ctx); err != nil {
			t.Logf("failed to terminate postgres container: %v", err)
		}
	})

	connStr, err := container.ConnectionString(ctx, "sslmode=disable")
	if err != nil {
		t.Fatalf("failed to get connection string: %v", err)
	}

	pool, err := pgxpool.New(ctx, connStr)
	if err != nil {
		t.Fatalf("failed to connect to postgres: %v", err)
	}
	t.Cleanup(func() { pool.Close() })

	schema, err := readSchema()
	if err != nil {
		t.Fatalf("failed to read schema.sql: %v", err)
	}

	if _, err := pool.Exec(ctx, schema); err != nil {
		t.Fatalf("failed to apply schema: %v", err)
	}

	q := queries.New(pool)
	return &TestDB{Pool: pool, Queries: q}
}

// readSchema finds and reads the schema.sql file relative to this source file.
func readSchema() (string, error) {
	_, thisFile, _, _ := runtime.Caller(0)
	// thisFile is .../api/internal/testutil/testdb.go
	// schema is at .../api/internal/db/schema.sql
	schemaPath := filepath.Join(filepath.Dir(thisFile), "..", "db", "schema.sql")
	data, err := os.ReadFile(schemaPath)
	if err != nil {
		return "", err
	}
	return string(data), nil
}
