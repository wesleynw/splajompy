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

-- name: GetUserByUsername :one
SELECT user_id, email, username, created_at, name
FROM users
WHERE username = $1
LIMIT 1;

-- name: GetUserByIdentifier :one
SELECT user_id, email, username, created_at, name
FROM users
WHERE email = $1 OR username = $1
LIMIT 1;

-- name: GetUsernameLike :many
SELECT *
FROM users
WHERE username LIKE $1
AND NOT EXISTS (
    SELECT 1
    FROM block
    WHERE block.user_id = users.user_id AND target_user_id = $3
)
LIMIT $2;

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

-- name: CreateVerificationCode :exec
INSERT INTO "verificationCodes" (code, user_id, expires_at)
VALUES ($1, $2, $3)
ON CONFLICT (user_id) DO UPDATE
SET code = $1, expires_at = $3;

-- name: GetVerificationCode :one
SELECT *
FROM "verificationCodes"
WHERE user_id = $1 and code = $2
LIMIT 1;

-- name: UpdateUserName :exec
UPDATE users
SET name = $2
WHERE user_id = $1;

-- name: UpdateUserBio :exec
INSERT INTO bios (user_id, text)
VALUES ($1, $2)
ON CONFLICT (user_id)
DO UPDATE SET text = $2;

-- name: BlockUser :exec
INSERT INTO block (user_id, target_user_id)
VALUES ($1, $2)
ON CONFLICT DO NOTHING;

-- name: UnblockUser :exec
DELETE FROM block
WHERE user_id = $1 AND target_user_id = $2;

-- name: GetIsUserBlockingUser :one
SELECT EXISTS (
  SELECT 1
  FROM block
  WHERE user_id = $1 AND target_user_id = $2
);