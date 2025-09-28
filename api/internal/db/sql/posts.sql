-- name: GetPostsIdsByUserId :many
SELECT post_id
FROM posts
WHERE user_id = $1
ORDER BY created_at DESC
OFFSET $2
LIMIT $3;

-- name: GetPostIdsByUserIdCursor :many
SELECT post_id
FROM posts
WHERE user_id = $1 AND ($3::timestamp IS NULL OR posts.created_at < $3::timestamp)
ORDER BY created_at DESC
LIMIT $2;

-- name: GetPostIdsByFollowing :many
SELECT post_id
FROM posts
WHERE posts.user_id = $1 OR EXISTS (
  SELECT 1
  FROM follows
  WHERE follows.follower_id = $1 AND following_id = posts.user_id
) AND NOT EXISTS (
    SELECT 1
    FROM block
    WHERE user_id = $1 AND target_user_id = posts.user_id
)
ORDER BY posts.created_at DESC
LIMIT $2
OFFSET $3;

-- name: GetAllPostIds :many
SELECT post_id
FROM posts
WHERE NOT EXISTS (
    SELECT 1
    FROM block
    WHERE block.user_id = $3 AND target_user_id = posts.user_id
)
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
INSERT INTO posts (user_id, text, facets, attributes)
VALUES ($1, $2, $3, $4)
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

-- name: GetAllImagesByUserId :many
SELECT images.*
FROM images
JOIN posts ON images.post_id = posts.post_id
WHERE posts.user_id = $1;

-- name: GetPostIdsForMutualFeed :many
WITH user_relationships AS (
  SELECT posts.post_id, posts.user_id,
    CASE 
      WHEN posts.user_id = $1 THEN 'own'
      WHEN f.follower_id IS NOT NULL THEN 'friend'
      ELSE 'mutual'
    END as relationship_type
  FROM posts
  LEFT JOIN follows f ON f.follower_id = $1 AND f.following_id = posts.user_id
  WHERE (posts.user_id = $1 OR f.follower_id IS NOT NULL OR 
         EXISTS (SELECT 1 FROM follows f1 
                 INNER JOIN follows f2 ON f1.following_id = f2.follower_id 
                 WHERE f1.follower_id = $1 AND f2.following_id = posts.user_id))
    AND NOT EXISTS (SELECT 1 FROM block WHERE user_id = $1 AND target_user_id = posts.user_id)
)
SELECT post_id, user_id, relationship_type, 
  CASE WHEN relationship_type = 'mutual' THEN 
    (SELECT ARRAY_AGG(u.username) FROM follows f1 
     INNER JOIN follows f2 ON f1.following_id = f2.follower_id 
     INNER JOIN users u ON f2.follower_id = u.user_id 
     WHERE f1.follower_id = $1 AND f2.following_id = user_relationships.user_id LIMIT 5)
  ELSE NULL END as mutual_usernames
FROM user_relationships
ORDER BY (SELECT created_at FROM posts WHERE posts.post_id = user_relationships.post_id) DESC
LIMIT $2 OFFSET $3;

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

-- name: GetAllPostIdsCursor :many
SELECT post_id
FROM posts
WHERE NOT EXISTS (
    SELECT 1
    FROM block
    WHERE block.user_id = $3 AND target_user_id = posts.user_id
) AND ($2::timestamp IS NULL OR posts.created_at < $2::timestamp)
ORDER BY posts.created_at DESC
LIMIT $1;

-- name: GetPostIdsByFollowingCursor :many
SELECT post_id
FROM posts
WHERE (posts.user_id = $1 OR EXISTS (
  SELECT 1
  FROM follows
  WHERE follows.follower_id = $1 AND following_id = posts.user_id
)) AND NOT EXISTS (
    SELECT 1
    FROM block
    WHERE user_id = $1 AND target_user_id = posts.user_id
) AND ($3::timestamp IS NULL OR posts.created_at < $3::timestamp)
ORDER BY posts.created_at DESC
LIMIT $2;

-- name: GetPostIdsForMutualFeedCursor :many
WITH user_relationships AS (
  SELECT posts.post_id, posts.user_id,
    CASE 
      WHEN posts.user_id = $1 THEN 'own'
      WHEN f.follower_id IS NOT NULL THEN 'friend'
      ELSE 'mutual'
    END as relationship_type
  FROM posts
  LEFT JOIN follows f ON f.follower_id = $1 AND f.following_id = posts.user_id
  WHERE (posts.user_id = $1 OR f.follower_id IS NOT NULL OR 
         EXISTS (SELECT 1 FROM follows f1 
                 INNER JOIN follows f2 ON f1.following_id = f2.follower_id 
                 WHERE f1.follower_id = $1 AND f2.following_id = posts.user_id))
    AND NOT EXISTS (SELECT 1 FROM block WHERE user_id = $1 AND target_user_id = posts.user_id)
    AND ($3::timestamp IS NULL OR posts.created_at < $3::timestamp)
)
SELECT post_id, user_id, relationship_type, 
  CASE WHEN relationship_type = 'mutual' THEN 
    (SELECT ARRAY_AGG(u.username) FROM follows f1 
     INNER JOIN follows f2 ON f1.following_id = f2.follower_id 
     INNER JOIN users u ON f2.follower_id = u.user_id 
     WHERE f1.follower_id = $1 AND f2.following_id = user_relationships.user_id LIMIT 5)
  ELSE NULL END as mutual_usernames
FROM user_relationships
ORDER BY (SELECT created_at FROM posts WHERE posts.post_id = user_relationships.post_id) DESC
LIMIT $2;

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
