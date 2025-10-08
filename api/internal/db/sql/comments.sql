-- name: GetCommentById :one
SELECT *
FROM comments
WHERE comment_id = $1
LIMIT 1;

-- name: GetCommentsByPostId :many
SELECT
  comments.comment_id,
  comments.post_id,
  comments.user_id,
  text,
  facets,
  comments.created_at,
  users.username,
  users.name
FROM comments
JOIN users ON comments.user_id = users.user_id
WHERE comments.post_id = $1
AND NOT EXISTS (
    SELECT 1
    FROM block
    WHERE block.user_id = $1 AND target_user_id = comments.user_id
)
ORDER BY comments.created_at DESC;

-- name: AddCommentToPost :one
INSERT INTO comments (post_id, user_id, text, facets)
VALUES ($1, $2, $3, $4)
RETURNING *;

-- name: DeleteComment :exec
DELETE FROM comments
WHERE comment_id = $1;

-- name: GetTopLikedCommentForPost :one
SELECT
  c.comment_id,
  c.post_id,
  c.user_id,
  c.text,
  c.facets,
  c.created_at,
  u.username,
  u.name,
  COUNT(l.user_id) as like_count
FROM comments c
JOIN users u ON c.user_id = u.user_id
LEFT JOIN likes l ON c.comment_id = l.comment_id AND l.is_post = FALSE
WHERE c.post_id = $1
AND NOT EXISTS (
    SELECT 1
    FROM block
    WHERE block.user_id = $2 AND target_user_id = c.user_id
)
GROUP BY c.comment_id, u.username, u.name
ORDER BY like_count DESC, c.created_at DESC
LIMIT 1;