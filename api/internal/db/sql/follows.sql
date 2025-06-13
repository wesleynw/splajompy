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
FROM follows f1
INNER JOIN follows f2 ON f1.following_id = f2.following_id
INNER JOIN users u ON f1.following_id = u.user_id
WHERE f1.follower_id = $1 
  AND f2.follower_id = $2
  AND f1.following_id != $1 
  AND f1.following_id != $2
LIMIT 5;