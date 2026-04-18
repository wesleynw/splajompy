package utilities

import "regexp"

var (
	UsernamePattern = `[a-zA-Z0-9](?:[a-zA-Z0-9._]*[a-zA-Z0-9])?`
	MentionRegex    = regexp.MustCompile(`(?:^|[\s])@(` + UsernamePattern + `)`)
	UsernameRegex   = regexp.MustCompile(`^` + UsernamePattern + `$`)
	EmailRegex      = regexp.MustCompile(`^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$`)
)
