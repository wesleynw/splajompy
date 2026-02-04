package templates

import (
	"bytes"
	"text/template"
)

type SupportEmailData struct {
	Username string
	Text     string
}

func GenerateSupportEmail(username, text string) (string, error) {
	tmpl := `From: @{{.Username}}

{{.Text}}`

	t, err := template.New("support").Parse(tmpl)
	if err != nil {
		return "", err
	}

	data := SupportEmailData{
		Username: username,
		Text:     text,
	}

	var buf bytes.Buffer
	if err := t.Execute(&buf, data); err != nil {
		return "", err
	}

	return buf.String(), nil
}
