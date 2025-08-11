FROM golang:1.24.6 AS builder

WORKDIR /app

COPY go.mod go.sum ./

RUN go mod download

COPY . ./

RUN CGO_ENABLED=0 GOOS=linux go build -o main ./cmd/api

FROM builder AS tester
RUN go test -v ./...

FROM gcr.io/distroless/static-debian11 AS runner

WORKDIR /

COPY --from=builder /app/main /main

EXPOSE 8080

USER nonroot:nonroot

ENTRYPOINT ["/main"]
