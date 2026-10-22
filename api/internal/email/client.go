package email

import "github.com/resend/resend-go/v3"

type Client interface {
	SendEmail(request *resend.SendEmailRequest) (*resend.SendEmailResponse, error)
}
