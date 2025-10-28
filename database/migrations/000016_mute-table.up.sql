CREATE TABLE IF NOT EXISTS mute (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    target_user_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT unique_user_target_user_id_mute UNIQUE(user_id, target_user_id),
    CONSTRAINT check_no_self_mute CHECK (user_id != target_user_id)
);
