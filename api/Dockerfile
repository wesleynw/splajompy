# https://docs.docker.com/guides/golang/build-images/

FROM golang:1.27.1 AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -trimpath -o main ./cmd/api

FROM gcr.io/distroless/static-debian13:nonroot AS runner
WORKDIR /app
COPY --from=builder /app/main /main

EXPOSE 8080
USER nonroot:nonroot
ENTRYPOINT ["/main"]
