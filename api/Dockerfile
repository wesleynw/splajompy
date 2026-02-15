# https://docs.docker.com/guides/golang/build-images/

FROM golang:1.26.0 AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o main ./cmd/api

FROM builder AS tester
RUN go test -v ./...

FROM gcr.io/distroless/static-debian13 AS runner
WORKDIR /app
COPY --from=builder /app/main /main

EXPOSE 8080
USER nonroot:nonroot
ENTRYPOINT ["/main"]
