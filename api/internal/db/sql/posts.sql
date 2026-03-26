-- name: GetCommentCountByPostID :one
SELECT COUNT(*)
FROM comments
WHERE post_id = $1;

-- name: InsertPost :one
INSERT INTO posts (user_id, text, facets, attributes, visibilityType)
VALUES ($1, $2, $3, $4, $5)
RETURNING *;

-- name: DeletePost :exec
DELETE FROM posts
WHERE post_id = $1;

-- name: InsertImage :one
INSERT INTO images (height, width, image_blob_url)
VALUES ($1, $2, $3)
RETURNING *;

-- name: InsertPostImage :exec
INSERT INTO post_images (post_id, image_id, display_order)
VALUES ($1, $2, $3);

-- name: GetImagesByPostId :many
SELECT images.*
FROM images
JOIN post_images ON images.image_id = post_images.image_id
WHERE post_images.post_id = $1
ORDER BY post_images.display_order ASC;

-- name: GetAllImagesByUserId :many
SELECT images.*
FROM images
JOIN post_images ON images.image_id = post_images.image_id
JOIN posts ON posts.post_id = post_images.post_id
WHERE posts.user_id = $1;

-- name: GetPollVotesGrouped :many
SELECT option_index, COUNT(*) AS count
FROM poll_vote
WHERE post_id = $1
GROUP BY option_index;

-- name: GetUserVoteInPoll :one
SELECT option_index
FROM poll_vote
WHERE post_id = $1 AND user_id = $2;

-- name: InsertVote :exec
INSERT INTO poll_vote (post_id, user_id, option_index)
VALUES ($1, $2, $3) ON CONFLICT DO NOTHING;

-- name: PinPost :exec
UPDATE users
SET pinned_post_id = $2
WHERE user_id = $1;

-- name: UnpinPost :exec
UPDATE users
SET pinned_post_id = NULL
WHERE user_id = $1;

-- name: GetPinnedPostId :one
SELECT pinned_post_id
FROM users
WHERE user_id = $1;
