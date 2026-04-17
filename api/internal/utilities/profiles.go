package utilities

import (
	"log/slog"
	"os"

	"github.com/grafana/pyroscope-go"
)

func InitializeProfiling() {
	_, err := pyroscope.Start(pyroscope.Config{
		ApplicationName:   "splajompy-api",
		ServerAddress:     "https://profiles-prod-001.grafana.net",
		Logger:            pyroscope.StandardLogger,
		BasicAuthUser:     os.Getenv("PYROSCOPE_USER"),
		BasicAuthPassword: os.Getenv("PYROSCOPE_PW"),
	})

	if err != nil {
		slog.Warn("profiler could not start")
	}
}
