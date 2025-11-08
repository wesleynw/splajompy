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
SELECT *
FROM users
WHERE user_id = $1
LIMIT 1;

-- name: GetUserByUsername :one
SELECT *
FROM users
WHERE username = $1
LIMIT 1;

-- name: GetUserByIdentifier :one
SELECT *
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

-- name: UpdateSessionExpiry :exec
UPDATE sessions
SET expires_at = $2
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

-- name: UpdateUserDisplayProperties :exec
UPDATE users
SET user_display_properties = $2
WHERE user_id = $1;

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

-- name: MuteUser :exec
INSERT INTO mute (user_id, target_user_id)
VALUES ($1, $2)
ON CONFLICT DO NOTHING;

-- name: UnmuteUser :exec
DELETE FROM mute
WHERE user_id = $1 AND target_user_id = $2;

-- name: GetIsUserMutingUser :one
SELECT EXISTS (
  SELECT 1
  FROM mute
  WHERE user_id = $1 AND target_user_id = $2
);

-- name: DeleteUserById :exec
DELETE FROM users
WHERE user_id = $1;

-- name: UserSearchWithHeuristics :many
WITH results AS (
    SELECT DISTINCT ON (user_id)
    user_id, username, name, is_verified, tier, score
FROM (
    SELECT users.user_id, users.username, users.name, users.is_verified, 1 as tier, 1.0 as score
    FROM users
    WHERE users.username = $1 OR users.name = $1

    UNION ALL

    SELECT users.user_id, users.username, users.name, users.is_verified, 2 as tier, 0.9 as score
    FROM users
    WHERE (users.username ILIKE $1 || '%' OR users.name ILIKE $1 || '%')
    AND users.username != $1
    AND (users.name != $1 OR users.name IS NULL)

    UNION ALL

    SELECT users.user_id, users.username, users.name, users.is_verified, 3 as tier, 0.7 as score
    FROM users
    WHERE (users.username ILIKE '%' || $1 || '%' OR users.name ILIKE '%' || $1 || '%')
    AND users.username NOT ILIKE $1 || '%'
    AND (users.name NOT ILIKE $1 || '%' OR users.name IS NULL)

    UNION ALL

    SELECT users.user_id, users.username, users.name, users.is_verified, 4 as tier,
    GREATEST(similarity(users.username, $1), similarity(COALESCE(users.name, ''), $1)) as score
    FROM users
    WHERE (users.username % $1 OR users.name % $1)
    AND users.username NOT ILIKE '%' || $1 || '%'
    AND (users.name NOT ILIKE '%' || $1 || '%' OR users.name IS NULL)
    AND (similarity(users.username, $1) > 0.3 OR similarity(COALESCE(users.name, ''), $1) > 0.3)
    ) sub
ORDER BY user_id, tier, score DESC
    )
SELECT r.user_id, r.username, r.name, r.is_verified, r.tier, r.score
FROM results r
WHERE NOT EXISTS (
    SELECT 1
    FROM block
    WHERE block.user_id = r.user_id AND target_user_id = $3
)
ORDER BY r.tier, r.score DESC, r.username
    LIMIT $2;
