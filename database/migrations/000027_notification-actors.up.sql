CREATE TABLE notification_actors (
    id SERIAL PRIMARY KEY,
    notification_id INT NOT NULL REFERENCES notifications(notification_id) ON DELETE CASCADE ,
    user_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (notification_id, user_id)
);
