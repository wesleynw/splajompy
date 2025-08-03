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

-- name: GetReadNotificationsForUserIdWithTimeOffset :many
SELECT *
FROM notifications 
WHERE user_id = $1 AND viewed = TRUE AND created_at < $2
ORDER BY created_at DESC
LIMIT $3;

-- name: GetUnreadNotificationsForUserIdWithTimeOffset :many
SELECT *
FROM notifications 
WHERE user_id = $1 AND viewed = FALSE AND created_at < $2
ORDER BY created_at DESC
LIMIT $3;

-- name: FindUnreadLikeNotification :one
SELECT *
FROM notifications 
WHERE user_id = $1 
  AND notification_type = 'like'
  AND viewed = FALSE
  AND (($2::int IS NULL AND post_id = $3 AND comment_id IS NULL) OR 
       ($2::int IS NOT NULL AND post_id = $3 AND comment_id = $2))
ORDER BY created_at DESC
LIMIT 1;

-- name: DeleteNotificationById :exec
DELETE FROM notifications 
WHERE notification_id = $1;