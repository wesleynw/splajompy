package middleware

import (
	"log/slog"
	"net/http"

	"connectrpc.com/connect/v2"
	"connectrpc.com/connect/v2/connecthttp"
	"splajompy.com/api/v2/internal/utilities"
)

// ErrorWriter uses the REST JSON format unless configured for RPC.
// RPC errors preserve caller messages except for internal failures.
type ErrorWriter struct {
	connect *connecthttp.ErrorWriter
}

func NewConnectErrorWriter() ErrorWriter {
	return ErrorWriter{connect: connecthttp.NewErrorWriter()}
}

func (e ErrorWriter) Write(w http.ResponseWriter, r *http.Request, status int, message string) {
	if e.connect == nil {
		utilities.HandleError(w, status, message)
		return
	}

	code := connect.CodeInternal
	switch status {
	case http.StatusBadRequest:
		code = connect.CodeInvalidArgument
	case http.StatusUnauthorized:
		code = connect.CodeUnauthenticated
	case http.StatusUpgradeRequired:
		code = connect.CodeFailedPrecondition
	default:
		message = http.StatusText(http.StatusInternalServerError)
	}
	if err := e.connect.Write(w, r, connect.NewError(code, message)); err != nil {
		slog.ErrorContext(r.Context(), "failed to write RPC error", "error", err)
	}
}
