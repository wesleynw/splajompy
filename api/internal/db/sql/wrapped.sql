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
