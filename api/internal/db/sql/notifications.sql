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

-- name: InsertNotification :exec
INSERT INTO notifications (user_id, post_id, comment_id, message, facets, link, notification_type)
VALUES ($1, $2, $3, $4, $5, $6, $7);