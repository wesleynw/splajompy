package templates

import (
	"bytes"
	"html/template"
)

type VerificationEmailData struct {
	Code string
}

func GenerateVerificationEmail(code string) (string, error) {
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

	t, err := template.New("verification").Parse(tmpl)
	if err != nil {
		return "", err
	}

	data := VerificationEmailData{
		Code: code,
	}

	var buf bytes.Buffer
	if err := t.Execute(&buf, data); err != nil {
		return "", err
	}

	return buf.String(), nil
}
