package templates

import (
	"bytes"
	"html/template"
)

// VerificationEmailData holds the data needed for the template
type VerificationEmailData struct {
	Code string
}

// GenerateVerificationEmail creates an HTML email with the verification code
func GenerateVerificationEmail(code string) (string, error) {
	// Define the HTML template
	tmpl := `
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Verification Code</title>
</head>
<body>
    <div style="font-family: Arial, sans-serif; line-height: 1.6; padding: 20px; background-color: #f9f9f9; color: #333; border: 1px solid #ddd; border-radius: 8px; max-width: 400px;">
        <h2 style="font-size: 24px; margin: 0 0 20px; color: #222;">Verification Code</h2>
        <div style="font-size: 32px; font-weight: bold; padding: 10px 20px; border-radius: 4px; display: inline-block; letter-spacing: 0.1em; margin-bottom: 20px;">
            {{.Code}}
        </div>
        <p style="font-size: 16px; margin: 0; color: #555;">
            This code will expire in <strong>5 minutes</strong>.
        </p>
    </div>
</body>
</html>
`

	// Parse the template
	t, err := template.New("verification").Parse(tmpl)
	if err != nil {
		return "", err
	}

	// Execute the template with the provided code
	data := VerificationEmailData{
		Code: code,
	}

	var buf bytes.Buffer
	if err := t.Execute(&buf, data); err != nil {
		return "", err
	}

	return buf.String(), nil
}

// Usage example:
// func main() {
//     code, _ := GenerateOTCCode() // Your code generation function
//     htmlEmail, err := GenerateVerificationEmail(code)
//     if err != nil {
//         log.Fatal(err)
//     }
//
//     // Use with email service like Resend:
//     // client := resend.NewClient("re_123456789")
//     // params := &resend.SendEmailRequest{
//     //     From:    "verification@yourdomain.com",
//     //     To:      []string{"user@example.com"},
//     //     Subject: "Your Verification Code",
//     //     HTML:    htmlEmail,
//     // }
//     // resp, err := client.Emails.Send(context.Background(), params)
// }
