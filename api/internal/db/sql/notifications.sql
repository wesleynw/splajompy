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
SELECT notifications.*
FROM notifications
LEFT JOIN posts ON notifications.post_id = posts.post_id
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
    ) AND (
        notifications.post_id IS NULL
        OR posts.visibilityType = 0 -- public
        OR posts.user_id = $1
        OR EXISTS (
            SELECT 1
            FROM user_relationship
            WHERE user_id = posts.user_id
                AND target_user_id = $1
                AND user_relationship.created_at < posts.created_at
        )
    )
ORDER BY notifications.created_at DESC
LIMIT $3;

-- name: FindLikeNotificationForPost :one
SELECT *
FROM notifications
WHERE user_id = $1
  AND notification_type = 'like'
  AND post_id = $2
  AND comment_id IS NULL
ORDER BY created_at DESC
LIMIT 1;

-- name: FindLikeNotificationForComment :one
SELECT *
FROM notifications
WHERE user_id = $1
  AND notification_type = 'like'
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
ON CONFLICT (notification_id, user_id) DO NOTHING;

-- name: DeleteNotificationActor :exec
DELETE FROM notification_actor
WHERE notification_id = $1 AND user_id = $2;

-- name: GetNotificationActors :many
SELECT user_id
FROM notification_actor
WHERE notification_id = $1
ORDER BY created_at DESC;

-- name: UpdateNotificationMessage :exec
UPDATE notifications
SET message = $2, facets = $3, created_at = CURRENT_TIMESTAMP, viewed = FALSE
WHERE notification_id = $1;

-- name: UpdateNotificationMessageOnly :exec
UPDATE notifications
SET message = $2, facets = $3
WHERE notification_id = $1;

-- name: InsertDeviceToken :exec
INSERT INTO device_token (user_id, device_id, device_token)
VALUES ($1, $2, $3)
ON CONFLICT (device_id) DO UPDATE SET device_token = $3, modified_at = CURRENT_TIMESTAMP;

-- name: GetDeviceTokensForUser :many
SELECT device_token
FROM device_token
WHERE user_id = $1;
