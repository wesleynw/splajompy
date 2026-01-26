CREATE TABLE user_relationship (
    user_id INT REFERENCES users(user_id),
    target_user_id INT REFERENCES users(user_id),
    created_at TIMESTAMP,
    PRIMARY KEY (user_id, target_user_id)
);

ALTER TABLE posts ADD COLUMN visibilityType INT NOT NULL DEFAULT 0;
