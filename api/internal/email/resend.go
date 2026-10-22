package email

import "github.com/resend/resend-go/v3"

type ResendEmailClient struct {
	client *resend.Client
}

func NewResendEmailClient(resendClient *resend.Client) *ResendEmailClient {
	return &ResendEmailClient{
		client: resendClient,
	}
}

func (c ResendEmailClient) SendEmail(request *resend.SendEmailRequest) (*resend.SendEmailResponse, error) {
	return c.client.Emails.Send(request)
}
