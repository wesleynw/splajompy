package templates

import (
	"bytes"
	"html/template"
	"splajompy.com/api/v2/internal/db/queries"
	"splajompy.com/api/v2/internal/models"
	"time"
)

type PostReportEmailData struct {
	ReporterUsername string
	PostID           int32
	PostText         string
	PostCreatedAt    time.Time
	ReportedAt       time.Time
	Images           []queries.Image
}

func GeneratePostReportEmail(reporterUsername string, post models.Post, images []queries.Image) (string, error) {
	tmpl := `
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Post Reported</title>
</head>
<body>
    <div style="font-family: Arial, sans-serif; line-height: 1.6; padding: 20px; background-color: #fff3cd; color: #333; border: 1px solid #ffeaa7; border-radius: 8px; max-width: 600px;">
        <h2 style="font-size: 24px; margin: 0 0 20px; color: #856404;">⚠️ Post Reported</h2>
        
        <div style="background-color: #fff; padding: 15px; border-radius: 4px; margin-bottom: 20px;">
            <p style="font-size: 16px; margin: 0 0 10px;"><strong>Reporter:</strong> @{{.ReporterUsername}}</p>
            <p style="font-size: 16px; margin: 0 0 10px;"><strong>Post ID:</strong> {{.PostID}}</p>
            <p style="font-size: 16px; margin: 0 0 10px;"><strong>Reported At:</strong> {{.ReportedAt.Format "Jan 2, 2006 15:04:05 UTC"}}</p>
        </div>

        <div style="background-color: #f8f9fa; padding: 15px; border-left: 4px solid #dc3545; border-radius: 4px; margin-bottom: 20px;">
            <h3 style="margin: 0 0 10px; color: #495057;">Post Content:</h3>
            <p style="font-size: 14px; margin: 0; color: #495057; white-space: pre-wrap;">{{.PostText}}</p>
            {{if .Images}}
            <div style="margin-top: 15px;">
                <h4 style="margin: 0 0 10px; color: #495057;">Images:</h4>
                {{range .Images}}
                <div style="margin-bottom: 10px;">
                    <img src="{{.ImageBlobUrl}}" alt="Post image" style="max-width: 300px; max-height: 300px; border-radius: 4px; border: 1px solid #dee2e6;">
                </div>
                {{end}}
            </div>
            {{end}}
            <p style="font-size: 12px; margin: 10px 0 0; color: #6c757d;">Originally posted: {{.PostCreatedAt.Format "Jan 2, 2006 15:04:05 UTC"}}</p>
        </div>
    </div>
</body>
</html>
`

	t, err := template.New("post-report").Parse(tmpl)
	if err != nil {
		return "", err
	}

	data := PostReportEmailData{
		ReporterUsername: reporterUsername,
		PostID:           int32(post.PostID),
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
