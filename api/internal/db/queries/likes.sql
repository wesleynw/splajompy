-- name: AddLike :exec
INSERT INTO likes (post_id, comment_id, user_id, is_post)
VALUES ($1, $2, $3, $4);

-- name: RemoveLike :exec
DELETE FROM likes
WHERE post_id = $1
AND user_id = $2
AND is_post = $3
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

-- name: GetPostLikesFromFollowers :many
SELECT users.username, users.user_id
FROM likes
INNER JOIN users ON likes.user_id = users.user_id
WHERE post_id = $1 AND comment_id IS NULL AND
    EXISTS (
        SELECT 1
        FROM follows
        WHERE follower_id = $2 AND following_id = likes.user_id
    );

-- name: HasLikesFromOthers :one
SELECT EXISTS (
    SELECT 1
    FROM likes
    WHERE post_id = $1 AND comment_id IS NULL AND
        user_id NOT IN (SELECT * FROM unnest($2::int[]))
);