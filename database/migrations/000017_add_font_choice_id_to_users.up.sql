-- Add JSONB column for user display properties
ALTER TABLE users ADD COLUMN IF NOT EXISTS user_display_properties JSONB NULL;
