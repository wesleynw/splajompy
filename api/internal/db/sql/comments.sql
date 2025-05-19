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
  comments.created_at,
  users.username,
  users.name
FROM comments
JOIN users ON comments.user_id = users.user_id
WHERE comments.post_id = $1
ORDER BY comments.created_at DESC;

-- name: AddCommentToPost :one
INSERT INTO comments (post_id, user_id, text)
VALUES ($1, $2, $3)
RETURNING *;