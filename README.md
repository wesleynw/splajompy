<div>
<picture>
    <img src="https://github.com/wesleynw/splajompy/blob/main/Assets/Assets.xcassets/icon-png.imageset/icon-ios-default.png" width="128px" alt="logo">
</picture>
</div>

# Splajompy
[![API Build](https://github.com/wesleynw/splajompy/actions/workflows/go.yml/badge.svg)](https://github.com/wesleynw/splajompy/actions/workflows/go.yml)
[![iOS Build](https://github.com/wesleynw/splajompy/actions/workflows/ios.yml/badge.svg)](https://github.com/wesleynw/splajompy/actions/workflows/ios.yml)

## What is this?
Splajompy is built rooted in the belief that mainstream social media has long stopped being an ideal place to connect with others online, and that what the internet needs isn't a public town square, but rather a small, safe, and familiar group of people.

Splajompy avoids the common social media designs that allow us to compare ourselves with others based on like or follower counts, which drive us towards treating posts as content, and instead nudges you to keep up with only people you know, or mutual friends.

Features:
- posts, likes, comments, images in both posts and comments
- profiles, bios, profile appearance customization
- polls, customizable feeds
- blocking, muting, following

Originally written as a full-stack Typescript application, Splajompy now has an API written in Go and a mobile app written almost entirely in SwiftUI to feel as native as possible.

## API Architecture
The API follows a domain-scoped architecture. Each domain (e.g. `post`, `user`, `auth`) lives in its own package under `internal/` and owns its store, service, and handler.

Each domain handler implements the `RouteRegistrar` interface:
```go
type RouteRegistrar interface {
    RegisterRoutes(public, withAuth func(string, func(http.ResponseWriter, *http.Request)))
}
```

The root handler in `internal/handler` holds a slice of `RouteRegistrar`s and registers routes for each domain.

`Store`s are currently a thin layer over the database, but exist as a natural place to add caching per domain in the future.

## Starting the API
You'll need to have a `.env` file in the `api` folder that includes a DB connection string, Resend API key, S3 API Key, and a few other things.

Start the API by running `go run cmd/api/main.go` from the `api` directory.

## SQLC
The API uses [SQLC](https://docs.sqlc.dev/en/stable/tutorials/getting-started-postgresql.html) to generate typed functions from database calls. Given a raw SQL query, you can have SQLC generate a function that can be called from a `querier` interface.

To do this, install SQLC locally, and run:
```bash
sqlc generate -f api/internal/db/sqlc.yaml
```

## DB Migrations
Migrations are handled with `golang-migrate`. To make changes to the DB, follow the linked guide below. This usually involves writing up and down migrations, which you can first push to the development DB, and then to production when new API code is merged.

[Database migrations in Go with golang-migrate](https://betterstack.com/community/guides/scaling-go/golang-migrate)

## Testing
Run the test suite from the `api` directory:
```bash
go test ./...
```

Docker must be installed as tests spin up a Postgres container.

## Linting

### Go Code
Before pushing Go code changes, run golangci-lint to check for issues:
```bash
# install golangci-lint (if not already installed)
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest

# Run linting from the api directory
cd api
golangci-lint run
```

### Swift Code
Before pushing Swift code changes, run the following command to format your code:
```bash
xcrun swift-format --in-place --recursive .
# or shorthand:
xcrun swift-format -ri .
```

Swift linting is also enforced via a GitHub action that runs on pull requests.

## Deployment
API code merged to the `main` branch is automatically deployed to the production API environment.

Merges that change any Swift code will also trigger a XCode Cloud build and release to an internal TestFlight group.
