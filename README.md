# Splajompy

## Starting the API

From the api subdirectory, run:

> `go run cmd/api/main.go`

## Generating [SQLC](https://docs.sqlc.dev/en/stable/tutorials/getting-started-postgresql.html) code

From the root of the repository, run:

> `sqlc generate -f internal/db/sqlc.yaml`

## DB Migrations
https://betterstack.com/community/guides/scaling-go/golang-migrate/
