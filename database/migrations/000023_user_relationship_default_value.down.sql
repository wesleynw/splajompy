ALTER TABLE user_relationship
  ALTER COLUMN created_at DROP NOT NULL,
  ALTER COLUMN created_at DROP DEFAULT;
