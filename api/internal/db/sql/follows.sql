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
SELECT DISTINCT u.username
FROM users u
WHERE EXISTS (
  SELECT 1
  FROM follows f
  WHERE f.follower_id = $1
    AND following_id = u.user_id
) AND EXISTS (
  SELECT 1
  FROM follows f
  WHERE f.follower_id = $2
    AND following_id = u.user_id
);

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
