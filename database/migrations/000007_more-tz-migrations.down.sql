ALTER TABLE users
ADD COLUMN created_at_old TIMESTAMP;
UPDATE users
SET created_at_old = created_at AT TIME ZONE 'UTC';
ALTER TABLE users
DROP COLUMN created_at;
ALTER TABLE users
RENAME COLUMN created_at_old TO created_at;
ALTER TABLE users
ALTER COLUMN created_at SET DEFAULT CURRENT_TIMESTAMP,
ALTER COLUMN created_at SET NOT NULL;

ALTER TABLE "verificationCodes"
ADD COLUMN expires_at_old TIMESTAMP;
UPDATE "verificationCodes"
SET expires_at_old = expires_at AT TIME ZONE 'UTC';
ALTER TABLE "verificationCodes"
DROP COLUMN expires_at;
ALTER TABLE "verificationCodes"
RENAME COLUMN expires_at_old TO expires_at;
ALTER TABLE "verificationCodes"
ALTER COLUMN expires_at SET NOT NULL;

ALTER TABLE notifications
ADD COLUMN created_at_old TIMESTAMP;
UPDATE notifications
SET created_at_old = created_at AT TIME ZONE 'UTC';
ALTER TABLE notifications
DROP COLUMN created_at;
ALTER TABLE notifications
RENAME COLUMN created_at_old TO created_at;
ALTER TABLE notifications
ALTER COLUMN created_at SET DEFAULT CURRENT_TIMESTAMP,
ALTER COLUMN created_at SET NOT NULL;

ALTER TABLE likes
ADD COLUMN created_at_old TIMESTAMP;
UPDATE likes
SET created_at_old = created_at AT TIME ZONE 'UTC';
ALTER TABLE likes
DROP COLUMN created_at;
ALTER TABLE likes
RENAME COLUMN created_at_old TO created_at;
ALTER TABLE likes
ALTER COLUMN created_at SET DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE follows
ADD COLUMN created_at_old TIMESTAMP;
UPDATE follows
SET created_at_old = created_at AT TIME ZONE 'UTC';
ALTER TABLE follows
DROP COLUMN created_at;
ALTER TABLE follows
RENAME COLUMN created_at_old TO created_at;
ALTER TABLE follows
ALTER COLUMN created_at SET DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE comments
ADD COLUMN created_at_old TIMESTAMP;
UPDATE comments
SET created_at_old = created_at AT TIME ZONE 'UTC';
ALTER TABLE comments
DROP COLUMN created_at;
ALTER TABLE comments
RENAME COLUMN created_at_old TO created_at;
ALTER TABLE comments
ALTER COLUMN created_at SET DEFAULT CURRENT_TIMESTAMP,
ALTER COLUMN created_at SET NOT NULL;

ALTER TABLE block
ADD COLUMN created_at_old TIMESTAMP;
UPDATE block
SET created_at_old = created_at AT TIME ZONE 'UTC';
ALTER TABLE block
DROP COLUMN created_at;
ALTER TABLE block
RENAME COLUMN created_at_old TO created_at;
ALTER TABLE block
ALTER COLUMN created_at SET DEFAULT CURRENT_TIMESTAMP,
ALTER COLUMN created_at SET NOT NULL;
