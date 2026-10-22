package email

import (
	"uuid"

	"github.com/resend/resend-go/v3"
)

type MockEmailClient struct {
	Requests []resend.SendEmailRequest
}

func NewMockEmailClient() *MockEmailClient {
	return &MockEmailClient{}
}

func (c MockEmailClient) SendEmail(request *resend.SendEmailRequest) (*resend.SendEmailResponse, error) {
	c.Requests = append(c.Requests, *request)
	return &resend.SendEmailResponse{
		Id: uuid.New().String(),
	}, nil
}

func (c MockEmailClient) ReturnAllRequests() []resend.SendEmailRequest {
	return c.Requests
}
