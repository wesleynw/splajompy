-- name: GetUserWithPasswordById :one
SELECT *
FROM users
WHERE user_id = $1
LIMIT 1;

-- name: GetUserWithPasswordByIdentifier :one
SELECT *
FROM users
WHERE email = $1 OR username = $1
LIMIT 1;

-- name: GetUserById :one
SELECT user_id, email, username, created_at, name
FROM users
WHERE user_id = $1
LIMIT 1;

-- name: GetUserByIdentifier :one
SELECT user_id, email, username, created_at, name
FROM users
WHERE email = $1 OR username = $1
LIMIT 1;


-- BIOS

-- name: GetBioByUserId :one
SELECT text
FROM bios
WHERE user_id = $1
LIMIT 1;

-- name: CreateSession :exec
INSERT INTO sessions (id, user_id, expires_at)
VALUES ($1, $2, $3);

-- name: DeleteSession :exec
DELETE FROM sessions
WHERE id = $1;

-- name: GetSessionById :one
SELECT *
FROM sessions
WHERE id = $1;


-- LIKES

-- name: AddLike :exec
INSERT INTO likes (post_id, comment_id, user_id, is_post)
VALUES ($1, $2, $3, $4);

-- DELETE FROM likes
-- WHERE post_id = $1 
--   AND user_id = $2
--   AND ($4 = FALSE AND comment_id = $3);

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

-- name: GetPostById :one
SELECT *
FROM posts
WHERE post_id = $1;

-- name: GetPostsIdsByUserId :many
SELECT post_id
FROM posts
WHERE user_id = $1
ORDER BY created_at DESC
OFFSET $2
LIMIT $3;

-- name: GetAllPostsByFollowing :many
SELECT
  posts.post_id, 
  posts.text, 
  posts.created_at, 
  users.user_id, 
  users.username, 
  users.name, 
  COUNT(DISTINCT comments.comment_id) AS commentCount,
  EXISTS (
    SELECT 1 
    FROM likes
    WHERE likes.post_id = posts.post_id
      AND likes.user_id = $1
      AND likes.comment_id IS NULL
  ) AS liked
FROM posts
LEFT JOIN users ON posts.user_id = users.user_id
LEFT JOIN comments on posts.post_id = comments.post_id
WHERE posts.user_id = $1 OR EXISTS (
  SELECT 1
  FROM follows
  WHERE follows.follower_id = $1 AND follows.following_id = posts.user_id
)
GROUP BY posts.post_id, users.user_id
ORDER BY posts.created_at DESC
LIMIT $2 
OFFSET $3;

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

-- name: GetImagesByPostId :many
SELECT *
FROM images
WHERE images.post_id = $1;