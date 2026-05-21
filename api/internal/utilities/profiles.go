package utilities

import (
	"log/slog"
	"os"

	"github.com/grafana/pyroscope-go"
)

// InitializeProfiling profiles the application using Pyroscope.
func InitializeProfiling() {
	_, err := pyroscope.Start(pyroscope.Config{
		ApplicationName:   "api",
		ServerAddress:     "https://profiles-prod-001.grafana.net",
		Logger:            nil,
		BasicAuthUser:     os.Getenv("PYROSCOPE_USER"),
		BasicAuthPassword: os.Getenv("PYROSCOPE_PW"),
	})

	if err != nil {
		slog.Warn("profiler could not start", "error", err)
	}
}
