-- name: GetPostsIdsByUserId :many
SELECT post_id
FROM posts
WHERE user_id = $1
ORDER BY created_at DESC
OFFSET $2
LIMIT $3;

-- name: GetPostIdsByFollowing :many
SELECT post_id
FROM posts
WHERE posts.user_id = $1 OR EXISTS (
  SELECT 1
  FROM follows
  WHERE follows.follower_id = $1 AND following_id = posts.user_id
)
ORDER BY posts.created_at DESC
LIMIT $2
OFFSET $3;

-- name: GetAllPostIds :many
SELECT post_id
FROM posts
ORDER BY posts.created_at DESC
LIMIT $1
OFFSET $2;

-- name: GetCommentCountByPostID :one
SELECT COUNT(*)
FROM comments
WHERE post_id = $1;

-- name: GetPostById :one
SELECT *
FROM posts
WHERE post_id = $1;

-- name: InsertPost :one
INSERT INTO posts (user_id, text, facets)
VALUES ($1, $2, $3)
RETURNING *;

-- name: DeletePost :exec
DELETE FROM posts
WHERE post_id = $1;

-- name: InsertImage :one
INSERT INTO images (post_id, height, width, image_blob_url, display_order)
VALUES ($1, $2, $3, $4, $5)
RETURNING *;

-- name: GetImagesByPostId :many
SELECT *
FROM images
WHERE images.post_id = $1
ORDER BY display_order ASC;