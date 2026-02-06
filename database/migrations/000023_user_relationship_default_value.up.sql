ALTER TABLE user_relationship
  ALTER COLUMN created_at TYPE TIMESTAMP,
  ALTER COLUMN created_at SET DEFAULT now(),
  ALTER COLUMN created_at SET NOT NULL;
