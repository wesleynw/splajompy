package utilities

import "regexp"

var (
	usernamePattern = `[a-zA-Z0-9](?:[a-zA-Z0-9._]*[a-zA-Z0-9])?`
	MentionRegex    = regexp.MustCompile(`@(` + usernamePattern + `)`)
	UsernameRegex   = regexp.MustCompile(`^` + usernamePattern + `$`)
	EmailRegex      = regexp.MustCompile(`^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$`)
)
