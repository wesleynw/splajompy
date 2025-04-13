-- name: GetIsUsernameInUse :one
SELECT EXISTS (
  SELECT 1
  FROM users
  WHERE username = $1
);

-- name: GetIsEmailInUse :one
SELECT EXISTS (
  SELECT 1
  FROM users
  WHERE email = $1
);

-- name: CreateUser :one
INSERT INTO users (email, username, password)
VALUES ($1, $2, $3)
RETURNING *;

-- name: GetUserWithPasswordById :one
SELECT *
FROM users
WHERE user_id = $1
LIMIT 1;

-- name: GetUserWithPasswordByIdentifier :one
SELECT *
FROM users
WHERE email = $1 OR username = $1
LIMIT 1;

-- name: GetUserById :one
SELECT user_id, email, username, created_at, name
FROM users
WHERE user_id = $1
LIMIT 1;

-- name: GetUserByIdentifier :one
SELECT user_id, email, username, created_at, name
FROM users
WHERE email = $1 OR username = $1
LIMIT 1;

-- name: GetBioByUserId :one
SELECT text
FROM bios
WHERE user_id = $1
LIMIT 1;

-- name: CreateSession :exec
INSERT INTO sessions (id, user_id, expires_at)
VALUES ($1, $2, $3);

-- name: DeleteSession :exec
DELETE FROM sessions
WHERE id = $1;

-- name: GetSessionById :one
SELECT *
FROM sessions
WHERE id = $1;