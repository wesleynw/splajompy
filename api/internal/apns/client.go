package apns

import (
	"context"
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

func (c *Client) Push(context context.Context, notification *int) error {
	// req, err := http.NewRequestWithContext(context, http.MethodPost, "a", nil)
	// c.httpClient.Do(req)
	// res, err := c.httpClient.Post()
	return nil
}
