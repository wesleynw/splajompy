-- name: GetTotalPosts :one
SELECT COUNT(*)
FROM posts;

-- name: GetTotalComments :one
SELECT COUNT(*)
FROM comments;

-- name: GetTotalLikes :one
SELECT COUNT(*)
FROM likes;

-- name: GetTotalFollows :one
SELECT COUNT(*)
FROM follows;

-- name: GetTotalUsers :one
SELECT COUNT(*)
FROM users;

-- name: GetTotalNotifications :one
SELECT COUNT(*)
FROM notifications;
