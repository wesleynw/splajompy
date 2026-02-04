package templates

import (
	"bytes"
	"html/template"
	"time"

	"splajompy.com/api/v2/internal/db/queries"
	"splajompy.com/api/v2/internal/models"
)

type PostReportEmailData struct {
	ReporterUsername string
	AuthorUsername   string
	AuthorUserID     int
	PostID           int
	PostText         string
	PostCreatedAt    time.Time
	ReportedAt       time.Time
	Images           []queries.Image
}

func GeneratePostReportEmail(reporterUsername string, authorUsername string, authorUserID int, post models.Post, images []queries.Image) (string, error) {
	tmpl := `
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Post Reported</title>
</head>
<body>
    <h2>Post Reported</h2>

    <p><strong>Reporter:</strong> @{{.ReporterUsername}}</p>
    <p><strong>Post Author:</strong> @{{.AuthorUsername}} (ID: {{.AuthorUserID}})</p>
    <p><strong>Post ID:</strong> {{.PostID}}</p>
    <p><strong>Reported At:</strong> {{.ReportedAt.Format "Jan 2, 2006 15:04:05 UTC"}}</p>

    <h3>Post Content:</h3>
    <p>{{.PostText}}</p>
    {{if .Images}}
    <h4>Images:</h4>
    {{range .Images}}
    <div>
        <img src="{{.ImageBlobUrl}}" alt="Post image">
    </div>
    {{end}}
    {{end}}
    <p>Originally posted: {{.PostCreatedAt.Format "Jan 2, 2006 15:04:05 UTC"}}</p>
</body>
</html>
`

	t, err := template.New("post-report").Parse(tmpl)
	if err != nil {
		return "", err
	}

	data := PostReportEmailData{
		ReporterUsername: reporterUsername,
		AuthorUsername:   authorUsername,
		AuthorUserID:     authorUserID,
		PostID:           post.PostID,
		PostText:         post.Text,
		PostCreatedAt:    post.CreatedAt.UTC(),
		ReportedAt:       time.Now().UTC(),
		Images:           images,
	}

	var buf bytes.Buffer
	if err := t.Execute(&buf, data); err != nil {
		return "", err
	}

	return buf.String(), nil
}
