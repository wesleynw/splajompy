

-- name: GetImagesByPostId :many
SELECT *
FROM images
WHERE images.post_id = $1
ORDER BY display_order ASC;