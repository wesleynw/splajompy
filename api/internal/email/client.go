package email

import "github.com/resend/resend-go/v4"

type Client interface {
	SendEmail(request *resend.SendEmailRequest) (*resend.SendEmailResponse, error)
}
