ALTER TABLE sessions
DROP CONSTRAINT IF EXISTS sessions_user_id_users_user_id_fk;

ALTER TABLE sessions
ADD CONSTRAINT FOREIGN KEY (user_id) REFERENCES users(user_id);
