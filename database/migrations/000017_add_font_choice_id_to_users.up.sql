-- Add JSONB column for user display properties
ALTER TABLE users ADD COLUMN IF NOT EXISTS user_display_properties JSONB DEFAULT '{"fontChoiceId": 0}'::jsonb NOT NULL;
