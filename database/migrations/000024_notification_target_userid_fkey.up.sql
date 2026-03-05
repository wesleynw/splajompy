UPDATE notifications
SET target_user_id = NULL
WHERE target_user_id IS NOT NULL
    AND NOT EXISTS (
    SELECT 1 FROM users WHERE user_id = notifications.target_user_id
  );

ALTER TABLE notifications
ADD FOREIGN KEY (target_user_id) REFERENCES users(user_id) ON DELETE SET NULL;
