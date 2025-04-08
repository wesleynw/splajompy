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