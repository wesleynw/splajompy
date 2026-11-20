package email

import (
	"os"

	"github.com/resend/resend-go/v3"
)

type ResendEmailClient struct {
	client *resend.Client
}

func NewResendEmailClient() *ResendEmailClient {
	resendApiKey := os.Getenv("RESEND_API_KEY")

	return &ResendEmailClient{
		client: resend.NewClient(resendApiKey),
	}
}

func (c ResendEmailClient) SendEmail(request *resend.SendEmailRequest) (*resend.SendEmailResponse, error) {
	return c.client.Emails.Send(request)
}
