ALTER TABLE posts 
ADD COLUMN created_at_ts TIMESTAMP;

UPDATE posts 
SET created_at_ts = created_at AT TIME ZONE 'UTC';

ALTER TABLE posts 
DROP COLUMN created_at;

ALTER TABLE posts 
RENAME COLUMN created_at_ts TO created_at;

ALTER TABLE posts 
ALTER COLUMN created_at SET DEFAULT CURRENT_TIMESTAMP,
ALTER COLUMN created_at SET NOT NULL;
