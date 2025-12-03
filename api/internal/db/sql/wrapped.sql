-- name: WrappedGetAllUserPostsWithCursor :many
SELECT *
FROM posts
WHERE user_id = $1 AND (@cursor::timestamp IS NULL OR created_at < @cursor::timestamp)
ORDER BY created_at DESC
LIMIT $2;

-- name: WrappedGetAllUserCommentsWithCursor :many
SELECT *
FROM comments
WHERE user_id = $1 AND (@cursor::timestamp IS NULL OR created_at < @cursor)
ORDER BY created_at DESC
LIMIT $2;

-- name: WrappedGetAllUserLikesWithCursor :many
SELECT *
FROM likes
WHERE user_id = $1 AND (@cursor::timestamptz IS NULL OR created_at < @cursor::timestamptz)
ORDER BY created_at DESC
LIMIT $2;

-- name: GetTotalPostsForUser :one
SELECT COUNT(*)
FROM posts
WHERE user_id = $1 AND EXTRACT(YEAR FROM created_at) = 2025;

-- name: GetTotalCommentsForUser :one
SELECT COUNT(*)
FROM comments
WHERE user_id = $1 AND EXTRACT(YEAR FROM created_at) = 2025;

-- name: GetTotalLikesForUser :one
SELECT COUNT(*)
FROM likes
WHERE user_id = $1 AND EXTRACT(YEAR FROM created_at) = 2025;

-- name: GetTotalNotificationsForUser :one
SELECT COUNT(*)
FROM notifications
WHERE user_id = $1 AND EXTRACT(YEAR FROM created_at) = 2025;

-- name: WrappedGetAveragePostLength :one
SELECT avg(length(text))
FROM posts
WHERE EXTRACT(YEAR FROM created_at) = 2025;

-- name: WrappedGetAveragePostLengthForUser :one
SELECT avg(length(text))
FROM posts
WHERE user_id = $1 AND EXTRACT(YEAR FROM created_at) = 2025;

-- name: WrappedGetAverageImageCountPerPost :one
SELECT AVG(image_count)
FROM (
    SELECT COUNT(*) as image_count
    FROM images
    JOIN posts ON images.post_id = posts.post_id
    WHERE EXTRACT(YEAR FROM created_at) = 2025
    GROUP BY images.post_id
) subquery;

-- name: WrappedGetAverageImageCountPerPostForUser :one
SELECT AVG(image_count)
FROM (
    SELECT COUNT(*) as image_count
    FROM images
    JOIN posts ON images.post_id = posts.post_id
    WHERE user_id = $1 AND EXTRACT(YEAR FROM posts.created_at) = 2025
    GROUP BY images.post_id
) subquery;

-- name: WrappedGetMostLikedPostId :one
SELECT likes.post_id, COUNT(*)
FROM likes
JOIN posts ON likes.post_id = posts.post_id
WHERE posts.user_id = $1 AND comment_id IS NULL
    AND EXTRACT(YEAR FROM likes.created_at) = 2025
GROUP BY likes.post_id
ORDER BY COUNT(*) DESC;

-- name: WrappedGetUsersWhoGetMostLikesForPosts :many
SELECT
    u.user_id,
    COUNT(*) as like_count
FROM likes l
JOIN posts p ON l.post_id = p.post_id
JOIN users u ON p.user_id = u.user_id
WHERE l.user_id = $1 AND l.comment_id IS NULL
    AND EXTRACT(YEAR FROM likes.created_at) = 2025
GROUP BY u.user_id, u.username
ORDER BY like_count DESC;

-- name: WrappedGetUsersWhoGetMostLikesForComments :many
SELECT
    u.user_id,
    COUNT(*) as like_count
FROM likes l
JOIN comments c ON l.comment_id = c.comment_id
JOIN users u ON c.user_id = u.user_id
WHERE l.user_id = $1 AND l.comment_id IS NOT NULL
    AND EXTRACT(YEAR FROM likes.created_at) = 2025
GROUP BY u.user_id, u.username
ORDER BY like_count DESC;

-- name: WrappedGetUsersWhoGetMostComments :many
SELECT
    u.user_id,
    COUNT(*) as comment_count
FROM comments c
JOIN posts p ON c.post_id = p.post_id
JOIN users u ON p.user_id = u.user_id
WHERE c.user_id = $1 AND p.user_id != $1
    AND EXTRACT(YEAR FROM c.created_at) = 2025
GROUP BY u.user_id, u.username
ORDER BY comment_count DESC;
