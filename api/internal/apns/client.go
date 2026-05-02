package apns

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"

	"splajompy.com/api/v2/internal/apns/token"
)

const (
	DevelopmentServer = "https://api.sandbox.push.apple.com/"
	ProductionServer  = "https://api.push.apple.com/"
)

type Client struct {
	httpClient *http.Client
	baseUrl    string
	token      *token.Token
}

func NewClient(token *token.Token) *Client {
	return &Client{
		httpClient: &http.Client{},
		baseUrl:    DevelopmentServer,
		token:      token,
	}
}

func (c *Client) Push(ctx context.Context, notification *Notification) error {
	url := c.baseUrl + "3/device/" + notification.DeviceToken
	body, err := json.Marshal(notification.Payload)
	if err != nil {
		return err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return err
	}

	bearer, err := c.token.GetBearerToken()
	if err != nil {
		return err
	}

	req.Header.Add("authorization", "bearer "+*bearer)
	req.Header.Add("apns-topic", "splajompy.com.Splajompy.devW")

	res, err := c.httpClient.Do(req)
	if err != nil {
		slog.ErrorContext(ctx, err.Error())
		return err
	}
	defer res.Body.Close()

	body, err = io.ReadAll(res.Body)

	return nil
}
