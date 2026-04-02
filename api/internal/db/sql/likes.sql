-- name: AddLike :exec
INSERT INTO likes (post_id, comment_id, user_id)
VALUES ($1, $2, $3);

-- name: RemoveLike :exec
DELETE FROM likes
WHERE post_id = $1
AND user_id = $2
AND ($3 = TRUE OR comment_id = $4);

-- name: GetIsPostLikedByUser :one
SELECT EXISTS (
  SELECT 1
  FROM likes
  WHERE user_id = $1
    AND post_id = $2
    AND comment_id IS NULL
);

-- name: GetIsLikedByUser :one
SELECT EXISTS (
  SELECT 1
  FROM likes
  WHERE user_id = $1
  AND post_id = $2
  AND (
    CASE
      WHEN $4::boolean = FALSE THEN comment_id = $3
      ELSE comment_id IS NULL
    END
  )
);

-- name: GetPostLikes :many
SELECT users.username, users.user_id, users.is_verified
FROM likes
JOIN users ON likes.user_id = users.user_id
WHERE likes.post_id = $1
AND likes.user_id != $2
AND NOT EXISTS (
    SELECT 1 FROM block
    WHERE block.user_id = $2
        AND likes.user_id = block.target_user_id
) AND NOT EXISTS (
    SELECT 1 FROM block
    WHERE block.user_id = likes.user_id
        AND block.target_user_id = $2
)
LIMIT 3;
