CREATE TABLE IF NOT EXISTS poll_vote (
    id SERIAL PRIMARY KEY,
    post_id INT NOT NULL REFERENCES posts(post_id) ON DELETE CASCADE,
    user_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    option_index INT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(post_id, user_id)
);

ALTER TABLE posts ADD COLUMN IF NOT EXISTS attributes JSON;

