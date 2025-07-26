package templates

import (
	"bytes"
	"html/template"
)

type FeatureRequestEmailData struct {
	Username string
	Text     string
}

func GenerateFeatureRequestEmail(username, text string) (string, error) {
	tmpl := `
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Feature Request</title>
</head>
<body>
    <div style="font-family: Arial, sans-serif; line-height: 1.6; padding: 20px; background-color: #e3f2fd; color: #333; border: 1px solid #90caf9; border-radius: 8px; max-width: 600px;">
        <h2 style="font-size: 24px; margin: 0 0 20px; color: #1565c0;">💡 Feature Request</h2>
        
        <div style="background-color: #fff; padding: 15px; border-radius: 4px; margin-bottom: 20px;">
            <p style="font-size: 16px; margin: 0 0 10px;"><strong>From:</strong> @{{.Username}}</p>
        </div>

        <div style="background-color: #f8f9fa; padding: 15px; border-left: 4px solid #2196f3; border-radius: 4px;">
            <h3 style="margin: 0 0 10px; color: #495057;">Request Details:</h3>
            <p style="font-size: 14px; margin: 0; color: #495057; white-space: pre-wrap;">{{.Text}}</p>
        </div>
    </div>
</body>
</html>
`

	t, err := template.New("feature-request").Parse(tmpl)
	if err != nil {
		return "", err
	}

	data := FeatureRequestEmailData{
		Username: username,
		Text:     text,
	}

	var buf bytes.Buffer
	if err := t.Execute(&buf, data); err != nil {
		return "", err
	}

	return buf.String(), nil
}