ALTER TABLE notifications ADD COLUMN IF NOT EXISTS notification_type VARCHAR(50) NOT NULL DEFAULT 'default';

-- guess types for existing notifications
UPDATE notifications SET notification_type = 'like' WHERE message LIKE '%liked your%' AND notification_type = 'default';
UPDATE notifications SET notification_type = 'mention' WHERE message LIKE '%@%' AND notification_type = 'default';
UPDATE notifications SET notification_type = 'comment' WHERE message LIKE '%commented on%' AND notification_type = 'default';
