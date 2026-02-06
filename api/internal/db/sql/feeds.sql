-- name: GetAllPostIdsCursor :many
SELECT post_id
FROM posts
WHERE NOT EXISTS (
    SELECT 1
    FROM block
    WHERE block.user_id = @user_id::int AND target_user_id = posts.user_id
) AND NOT EXISTS (
    SELECT 1
    FROM mute
    WHERE mute.user_id = @user_id::int AND target_user_id = posts.user_id
) AND (
    posts.visibilityType = 0 -- public
    OR posts.user_id = @user_id::int
    OR EXISTS (
        SELECT 1
        FROM user_relationship
        WHERE user_id = posts.user_id
            AND target_user_id = @user_id::int
            AND user_relationship.created_at < posts.created_at
    )
) AND (@before::timestamp IS NULL OR posts.created_at < @before::timestamp)
ORDER BY posts.created_at DESC
LIMIT sqlc.arg('limit')::int;

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
) AND NOT EXISTS (
    SELECT 1
    FROM mute
    WHERE user_id = $1 AND target_user_id = posts.user_id
) AND (
    posts.visibilityType = 0 -- public
    OR posts.user_id = $1
    OR EXISTS (
        SELECT 1
        FROM user_relationship
        WHERE user_id = posts.user_id
            AND target_user_id = $1
            AND user_relationship.created_at < posts.created_at
    )
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
    AND NOT EXISTS (SELECT 1 FROM mute WHERE user_id = $1 AND target_user_id = posts.user_id)
    AND (
        posts.visibilityType = 0 -- public
        OR posts.user_id = $1
        OR EXISTS (
            SELECT 1
            FROM user_relationship
            WHERE user_id = posts.user_id
                AND target_user_id = $1
                AND user_relationship.created_at < posts.created_at
        )
    )
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

-- name: GetPostById :one
SELECT *
FROM posts
WHERE post_id = $1
AND (
    posts.visibilityType = 0 -- public
    OR posts.user_id = $2
    OR EXISTS (
        SELECT 1
        FROM user_relationship
        WHERE user_id = posts.user_id
            AND target_user_id = $2
            AND user_relationship.created_at < posts.created_at
    )
);

-- name: GetPostIdsByUserIdCursor :many
SELECT post_id
FROM posts
WHERE user_id = @target_user_id::int AND (@before::timestamp IS NULL OR posts.created_at < @before::timestamp)
AND (
    posts.visibilityType = 0 -- public
    OR posts.user_id = @user_id
    OR EXISTS (
        SELECT 1
        FROM user_relationship
        WHERE user_id = posts.user_id
            AND target_user_id = @user_id
            AND user_relationship.created_at < posts.created_at
    )
)
ORDER BY created_at DESC
LIMIT sqlc.arg('limit')::int;
