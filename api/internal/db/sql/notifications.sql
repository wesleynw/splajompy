-- name: GetNotificationsForUserId :many
SELECT *
FROM notifications
WHERE user_id = $1
ORDER BY created_at DESC
LIMIT $2
OFFSET $3;

-- name: GetNotificationById :one
SELECT *
FROM notifications
WHERE notification_id = $1
LIMIT 1;

-- name: MarkNotificationAsReadById :exec
UPDATE notifications
SET viewed = TRUE
WHERE notification_id = $1;

-- name: MarkAllNotificationsAsReadForUser :exec
UPDATE notifications
SET viewed = TRUE
WHERE user_id = $1;

-- name: UserHasUnreadNotifications :one
SELECT EXISTS (
  SELECT 1
  FROM notifications
  WHERE user_id = $1 AND viewed = FALSE
);

-- name: GetUserUnreadNotificationCount :one
SELECT COUNT(*)
FROM notifications
WHERE user_id = $1 AND viewed = FALSE;

-- name: GetUnreadNotificationsForUserId :many
SELECT *
FROM notifications
WHERE user_id = $1 AND viewed = FALSE
ORDER BY created_at DESC
LIMIT $2
OFFSET $3;

-- name: InsertNotification :one
INSERT INTO notifications (user_id, post_id, comment_id, message, facets, link, notification_type, target_user_id)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
RETURNING *;

-- name: GetNotificationsForUserIdWithTimeOffset :many
SELECT *
FROM notifications
WHERE notifications.user_id = $1 AND notifications.viewed = $4 AND notifications.created_at < $2
    AND (
        sqlc.narg('notification_type')::text IS NULL
            OR notifications.notification_type = sqlc.narg('notification_type')
    ) AND NOT EXISTS ( -- no notifications targeting blocked users
        SELECT 1 FROM block
        WHERE block.user_id = $1
            AND block.target_user_id = notifications.target_user_id
    ) AND NOT EXISTS ( -- no notifications referencing posts from blocked users
        SELECT 1 FROM block
        JOIN posts ON posts.post_id = notifications.post_id
        WHERE block.user_id = $1
            AND posts.user_id = block.target_user_id
    ) AND NOT EXISTS ( -- no notifications refering posts from users that have blocked this user
        SELECT 1 FROM block
        JOIN posts ON posts.post_id = notifications.post_id
        WHERE block.user_id = posts.user_id
            AND block.target_user_id = $1
    )
ORDER BY notifications.created_at DESC
LIMIT $3;

-- name: FindUnreadLikeNotificationForPost :one
SELECT *
FROM notifications
WHERE user_id = $1
  AND notification_type = 'like'
  AND viewed = FALSE
  AND post_id = $2
  AND comment_id IS NULL
ORDER BY created_at DESC
LIMIT 1;

-- name: FindUnreadLikeNotificationForComment :one
SELECT *
FROM notifications
WHERE user_id = $1
  AND notification_type = 'like'
  AND viewed = FALSE
  AND post_id = $2
  AND comment_id = $3
ORDER BY created_at DESC
LIMIT 1;

-- name: DeleteNotificationById :exec
DELETE FROM notifications
WHERE notification_id = $1;

-- name: InsertNotificationActor :exec
INSERT INTO notification_actor (notification_id, user_id)
VALUES ($1, $2)
ON CONFLICT DO NOTHING;

-- name: GetNotificationActors :many
SELECT user_id
FROM notification_actor
WHERE notification_id = $1
ORDER BY created_at DESC;

-- name: UpdateNotificationMessage :exec
UPDATE notifications
SET message = $2
WHERE notification_id = $1;
