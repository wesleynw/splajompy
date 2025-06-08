ALTER TABLE sessions
DROP CONSTRAINT sessions_user_id_users_user_id_fk;

ALTER TABLE sessions
ADD CONSTRAINT sessions_user_id_users_user_id_fk
FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE;

