-- name: GetIsUserFollowingUser :one
SELECT EXISTS (
  SELECT 1
  FROM follows
  WHERE follower_id = $1 AND following_id = $2
);

-- name: InsertFollow :exec
INSERT INTO follows (follower_id, following_id)
VALUES ($1, $2);

-- name: DeleteFollow :exec
DELETE FROM follows
WHERE following_id = $1 AND follower_id = $2;

-- name: GetMutualConnectionsForUser :many
SELECT u.username
FROM users u
INNER JOIN follows f0 ON f0.follower_id = $1 AND f0.following_id = u.user_id
INNER JOIN follows f1 ON f1.follower_id = $2 AND f1.following_id = u.user_id
ORDER BY f0.created_at DESC;

-- name: GetFollowersByUserId :many
SELECT u.user_id, u.email, u.username, u.created_at, u.name
FROM users u
INNER JOIN follows f ON u.user_id = f.follower_id
WHERE f.following_id = $1
ORDER BY f.created_at DESC
LIMIT $2 OFFSET $3;

-- name: GetFollowingByUserId :many
SELECT u.user_id, u.email, u.username, u.created_at, u.name
FROM users u
INNER JOIN follows f ON u.user_id = f.following_id
WHERE f.follower_id = $1
ORDER BY f.created_at DESC
LIMIT $2 OFFSET $3;

-- name: GetMutualsByUserId :many
SELECT DISTINCT u.user_id, u.email, u.username, u.created_at, u.name
FROM users u
INNER JOIN follows f1 ON f1.following_id = u.user_id AND f1.follower_id = $1
INNER JOIN follows f2 ON f2.following_id = u.user_id AND f2.follower_id = $2
ORDER BY u.created_at DESC
LIMIT $3 OFFSET $4;
