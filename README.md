<div>
<picture>
    <img src="https://github.com/wesleynw/splajompy/blob/b6e86190f1119f2741a293f3917d298707a0cc78/Assets/icons/snail-basic_icon.icon/Assets/new_snail.png" width="158px" alt="logo">
</picture>
</div>

# Splajompy
[![iOS Build](https://github.com/wesleynw/splajompy/actions/workflows/ios.yml/badge.svg)](https://github.com/wesleynw/splajompy/actions/workflows/ios.yml)
[![API Build](https://github.com/wesleynw/splajompy/actions/workflows/go.yml/badge.svg)](https://github.com/wesleynw/splajompy/actions/workflows/go.yml)

## What is Splajompy?
Splajompy /splʌd͡ʒɑmpi/ is a free, open-source social media application for iOS. 

Features:
- Posts, comments, likes, images, polls
- Following, tagging, muting, blocking
- Search, profiles, notifications

Free from:
- AI, ads, bots
- Short-form video content
- *The Algorithm*

Originally a full-stack Typescript application, Splajompy is now a native SwiftUI app with an API written in Go.

[iOS and macOS app download](https://apps.apple.com/us/app/splajompy/id6744034321)

## Architecture
The API follows a domain-scoped architecture. Each domain (e.g. `post`, `user`, `auth`) lives in its own package under `internal/` and implements its own store, service, and handler.

Each REST handler implements the `RESTRegistrar` interface:
```go
type RESTRegistrar interface {
    RegisterRESTRoutes(public, withAuth func(string, func(http.ResponseWriter, *http.Request)))
}
```

The root handler in `internal/handler` registers REST handlers from `handler.go` and Connect handlers from `connect_handler.go`. Connect handlers register services on one server. Authentication applies to every RPC.

`Store`s are currently a thin layer over the database, but exist as a natural place to add caching per domain in the future.

## Starting the API
Install the [Pulumi CLI](https://www.pulumi.com/docs/install/) and run `pulumi login`. Get access to `splajompy-org/splajompy/dev`. Add your public IP to the database allowlist only when using the shared development database.

Run from the repository root. `make dev` and the native Go command use the shared `splajompy-dev` database. Press `Ctrl+C` to stop the API.

### Docker
Install Docker, then run:

```bash
make dev
```

Run `make dev` again after code changes.

For local PostgreSQL, run `make local`. It applies migrations and seeds two users, `local_alice` and `local_bob`, both with password `localdev`. The API listens on port `8081`.

Use `make local-migrate` to apply migrations, `make local-rollback` to undo one, and `make local-seed` to restore missing sample data. `make local-stop` stops the containers and keeps the database.

### Native Go
Install Go, then run:

```bash
pulumi env run splajompy-org/splajompy/dev -- go -C api run ./cmd/api
```

## SQLC
The API uses [SQLC](https://docs.sqlc.dev/en/stable/tutorials/getting-started-postgresql.html) to generate typed functions from database calls. Given a raw SQL query, you can have SQLC generate a function that can be called from a `querier` interface.

To do this, install SQLC locally, and run:
```bash
sqlc generate -f api/internal/db/sqlc.yaml
```

## Connect RPC

Install [Buf](https://buf.build/docs/cli/installation/), then run `go generate ./...` from `api/` to generate Go code from `proto/`. Generator versions are managed in `api/go.mod`.

Run `buf generate` from `Splajompy/` to generate Swift code. Generator versions are pinned in `Splajompy/buf.gen.yaml`.

Apply migration `000029` before using notification streams. Set `DB_LISTEN_CONNECTION_STRING` to a direct or session-pooled connection to the same database if the query connection uses transaction pooling.

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
# install golangci-lint
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
API code merged to the `main` branch is automatically deployed to the production environment.

Merges that change any Swift code will also trigger a XCode Cloud build and release to an internal TestFlight group.
