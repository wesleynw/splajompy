package middleware

import (
	"context"
	"net/http"
	"time"
)

// StreamWriteTimeout replaces the response deadline with a limit for each write and flush.
// Waiting between messages does not consume the write allowance.
func StreamWriteTimeout(next http.Handler, timeout time.Duration) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		controller := http.NewResponseController(w)
		if err := controller.SetWriteDeadline(time.Time{}); err != nil {
			http.Error(w, "Unable to start stream", http.StatusInternalServerError)
			return
		}
		ctx, cancel := context.WithCancel(r.Context())
		defer cancel()
		writer := &streamResponseWriter{
			ResponseWriter: w,
			controller:     controller,
			timeout:        timeout,
			cancel:         cancel,
		}
		next.ServeHTTP(writer, r.WithContext(ctx))
		if writer.err == nil {
			// net/http can flush HTTP framing after the handler returns.
			_ = controller.SetWriteDeadline(time.Now().Add(timeout))
		}
	})
}

type streamResponseWriter struct {
	http.ResponseWriter
	controller *http.ResponseController
	timeout    time.Duration
	cancel     context.CancelFunc
	err        error
}

func (w *streamResponseWriter) Unwrap() http.ResponseWriter {
	return w.ResponseWriter
}

func (w *streamResponseWriter) Write(data []byte) (int, error) {
	var n int
	err := w.write(func() error {
		var err error
		n, err = w.ResponseWriter.Write(data)
		return err
	})
	return n, err
}

func (w *streamResponseWriter) WriteHeader(status int) {
	_ = w.write(func() error {
		w.ResponseWriter.WriteHeader(status)
		return nil
	})
}

func (w *streamResponseWriter) Flush() {
	_ = w.FlushError()
}

func (w *streamResponseWriter) FlushError() error {
	return w.write(w.controller.Flush)
}

func (w *streamResponseWriter) write(write func() error) error {
	if w.err != nil {
		return w.err
	}
	w.err = w.controller.SetWriteDeadline(time.Now().Add(w.timeout))
	if w.err == nil {
		w.err = write()
	}
	if w.err == nil {
		w.err = w.controller.SetWriteDeadline(time.Time{})
	}
	if w.err != nil {
		// http.Flusher cannot return errors. Cancellation stops the handler after a failed flush.
		w.cancel()
	}
	return w.err
}
