package templates

import (
	"bytes"
	"text/template"
)

type SignInEmailData struct {
	Username string
}

func GenerateSignInEmail(username string) (string, error) {
	tmpl := `Hi @{{.Username}},

We just detected a new sign-in to your Splajompy account.

If this wasn't you, god help you.`

	t, err := template.New("signin").Parse(tmpl)
	if err != nil {
		return "", err
	}

	data := SignInEmailData{
		Username: username,
	}

	var buf bytes.Buffer
	if err := t.Execute(&buf, data); err != nil {
		return "", err
	}

	return buf.String(), nil
}
