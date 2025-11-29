ALTER TABLE users
DROP CONSTRAINT IF EXISTS users_referral_code_key;

ALTER TABLE users
ALTER COLUMN referral_code SET DEFAULT '';

ALTER TABLE users
ALTER COLUMN referral_code DROP NOT NULL;
