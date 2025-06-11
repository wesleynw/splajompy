ALTER TABLE posts 
ADD COLUMN created_at_tz TIMESTAMPTZ;

UPDATE posts 
SET created_at_tz = created_at AT TIME ZONE 'UTC';

ALTER TABLE posts 
DROP COLUMN created_at;

ALTER TABLE posts 
RENAME COLUMN created_at_tz TO created_at;

ALTER TABLE posts 
ALTER COLUMN created_at SET DEFAULT NOW(),
ALTER COLUMN created_at SET NOT NULL;
