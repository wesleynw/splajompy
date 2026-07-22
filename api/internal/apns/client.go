package apns

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"os"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/codes"
	"go.opentelemetry.io/otel/metric"
	semconv "go.opentelemetry.io/otel/semconv/v1.40.0"
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

var tracer = otel.Tracer("apns-service")
var meter = otel.Meter("apns-service")

var ErrUnregisteredDevice = errors.New("device is reported unregisted")
var ErrBadDeviceToken = errors.New("device token is not valid")

type Client struct {
	httpClient *http.Client
	baseUrl    string
	bundleId   string
	token      *Token
}

func NewClient(token *Token) *Client {
	env := os.Getenv("ENVIRONMENT")
	var baseUrl string
	var bundleId string
	if env == "production" {
		baseUrl = ProductionServer
		bundleId = ProductionBundleId
	} else {
		baseUrl = DevelopmentServer
		bundleId = DevelopmentBundleId
	}
	return &Client{
		httpClient: &http.Client{},
		baseUrl:    baseUrl,
		bundleId:   bundleId,
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
	req.Header.Add("apns-topic", c.bundleId)
	req.Header.Add("apns-push-type", "alert")

	pushCounter, err := meter.Int64Counter("notification.push.counter", metric.WithDescription("Number of push notifications requested"), metric.WithUnit("{call}"))
	if err != nil {
		span.RecordError(err)
		span.SetStatus(codes.Error, err.Error())
		return err
	}

	res, err := c.httpClient.Do(req)
	defer func() {
		if err := res.Body.Close(); err != nil {
			slog.WarnContext(ctx, "failed to close response body", "error", err)
		}
	}()
	if err != nil {
		span.RecordError(err)
		span.SetStatus(codes.Error, err.Error())
		slog.ErrorContext(ctx, "apns request failed", "error", err)
		return err
	}
	pushCounter.Add(ctx, 1, metric.WithAttributes(semconv.HTTPResponseStatusCode(res.StatusCode)))

	if res.StatusCode != http.StatusOK {
		slog.ErrorContext(ctx, "apn did not return success code", "code", res.Status)

		bodyBytes, err := io.ReadAll(res.Body)
		if err != nil {
			span.RecordError(err)
			span.SetStatus(codes.Error, err.Error())
			slog.ErrorContext(ctx, "unable to react request body", "error", err)
			return err
		}
		var body NotificationResponse
		err = json.Unmarshal(bodyBytes, &body)
		if err != nil {
			span.RecordError(err)
			span.SetStatus(codes.Error, err.Error())
			slog.ErrorContext(ctx, "unable to unmarshall request body", "error", err)
			return err
		}
		slog.ErrorContext(ctx, "apns error", "status", res.Status, "reason", body.Reason)
		span.RecordError(err)
		span.SetStatus(codes.Error, body.Reason)
		if res.StatusCode == http.StatusGone {
			return ErrUnregisteredDevice
		} else if res.StatusCode == http.StatusBadRequest && body.Reason == "BadDeviceToken" {
			slog.WarnContext(ctx, "apns suggest device token is invalid")
			return ErrBadDeviceToken
		}
		return fmt.Errorf("apns error %s: %s", res.Status, body.Reason)
	} else {
		notificationId := res.Header.Get("apns-id")
		span.SetAttributes(attribute.String("notification.id", notificationId))
		span.SetAttributes(attribute.Int("http.status_code", res.StatusCode))

		return nil
	}
}
