<div align="center">
<picture>
    <img src="./Assets/logo.svg" width="128px">
</picture>
</div>

# Splajompy
[![API Build](https://github.com/wesleynw/splajompy/actions/workflows/go.yml/badge.svg)](https://github.com/wesleynw/splajompy/actions/workflows/go.yml)
[![iOS Build](https://github.com/wesleynw/splajompy/actions/workflows/ios.yml/badge.svg)](https://github.com/wesleynw/splajompy/actions/workflows/ios.yml)

## What is this?
Splajompy is a social app that allows users to do all the things you'd expect to be able to do on a social-media app, with an emphasis on only being able to see people in your social circle. Without emphasis on algorithmically shown content, Splajompy is a place to share interesting things with friends.

Originally written as a full-stack Typescript application, Splajompy now has an API written in Go and a mobile app written almost entirely in SwiftUI to feel as native as possible.

## Starting the API
You'll need to have a `.env` file in the `api` folder that includes a DB connection string, Resend API key, S3 API Key, and a few other things.

Start the API by running `go run cmd/api/main.go` from the `api` directory.

## SQLC
The API uses [SQLC](https://docs.sqlc.dev/en/stable/tutorials/getting-started-postgresql.html) to generate typed functions from database calls. Given a raw SQL query, you can have SQLC generate a function that can be called from a `querier` interface.

To do this, install SQLC locally, and run:
> `sqlc generate -f api/internal/db/sqlc.yaml`

## DB Migrations
Migrations are handled with `golang-migrate`. To make changes to the DB, follow the linked guide below. This usually involves writing up and down migrations, which you can first push to the development DB, and then to production when new API code is merged.

[Database migrations in Go with golang-migrate](https://betterstack.com/community/guides/scaling-go/golang-migrate)

## Deployment
API code merged to the `main` branch is automatically deployed to the production API environment.

Merges that change any Swift code will also trigger a XCode Cloud build and release to an internal TestFlight group.
