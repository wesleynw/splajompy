ALTER TABLE users
ALTER COLUMN referral_code SET NOT NULL;

ALTER TABLE users
ALTER COLUMN referral_code DROP DEFAULT;

ALTER TABLE users
ADD CONSTRAINT users_referral_code_key UNIQUE (referral_code);
