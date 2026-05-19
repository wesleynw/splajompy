package apns

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/codes"
	"go.opentelemetry.io/otel/metric"
	semconv "go.opentelemetry.io/otel/semconv/v1.37.0"
	"go.opentelemetry.io/otel/trace"
)

const (
	DevelopmentServer = "https://api.sandbox.push.apple.com/"
	ProductionServer  = "https://api.push.apple.com/"
)

const (
	DevelopmentBundleId = "splajompy.com.Splajompy.devW"
	ProductionBundleId  = "splajompy.com.Splajompy"
)

var tracer trace.Tracer = otel.Tracer("apns-service")
var meter metric.Meter = otel.Meter("apns-service")

type Client struct {
	httpClient *http.Client
	baseUrl    string
	token      *Token
}

func NewClient(token *Token) *Client {
	return &Client{
		httpClient: &http.Client{},
		baseUrl:    ProductionServer,
		token:      token,
	}
}

// Push a notification to Apple's APNs. Returns the notification id (UUID) upon success, otherwise an error message.
func (c *Client) Push(ctx context.Context, notification *Notification) error {
	ctx, span := tracer.Start(ctx, "apns.push",
		trace.WithSpanKind(trace.SpanKindClient),
		trace.WithAttributes(
			attribute.String("apns.device_token", notification.DeviceToken),
		),
	)
	defer span.End()

	url := c.baseUrl + "3/device/" + notification.DeviceToken

	body, err := json.Marshal(notification.Payload)
	if err != nil {
		span.RecordError(err)
		span.SetStatus(codes.Error, "failed to marshal payload")
		return err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		span.RecordError(err)
		span.SetStatus(codes.Error, "failed to build request")
		return err
	}

	bearer, err := c.token.GetBearerToken()
	if err != nil {
		span.RecordError(err)
		span.SetStatus(codes.Error, "failed to get bearer token")
		return err
	}

	req.Header.Add("authorization", "bearer "+*bearer)
	req.Header.Add("apns-topic", ProductionBundleId)
	req.Header.Add("apns-push-type", "alert")

	push_counter, err := meter.Int64Counter("push.counter", metric.WithDescription("Number of push notifications requested"), metric.WithUnit("{call}"))
	if err != nil {
		span.RecordError(err)
		span.SetStatus(codes.Error, err.Error())
		return err
	}

	res, err := c.httpClient.Do(req)
	push_counter.Add(ctx, 1, metric.WithAttributes(semconv.HTTPResponseStatusCode(res.StatusCode)))
	if err != nil {
		span.RecordError(err)
		slog.ErrorContext(ctx, "apns request failed", "error", err)
		bodyBytes, err := io.ReadAll(res.Body)
		var body NotificationResponse
		err = json.Unmarshal(bodyBytes, &body)
		span.SetStatus(codes.Error, body.Reason)
		return err
	}
	defer res.Body.Close()

	notification_id := res.Header.Get("apns-id")
	span.SetAttributes(attribute.String("notification.id", notification_id))
	span.SetAttributes(attribute.Int("http.status_code", res.StatusCode))

	body, err = io.ReadAll(res.Body)
	if err != nil {
		span.RecordError(err)
		span.SetStatus(codes.Error, "failed to read response")
		return err
	}

	if res.StatusCode != http.StatusOK {
		err := fmt.Errorf("apns: unexpected status %d: %s", res.StatusCode, body)
		span.RecordError(err)
		span.SetStatus(codes.Error, err.Error())
		slog.ErrorContext(ctx, "apns push failed", "status", res.StatusCode)
		return err
	}

	return nil
}
