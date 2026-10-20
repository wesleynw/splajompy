-- The existing migrations assume these tables exist.
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    username VARCHAR(100) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    name TEXT
);

CREATE TABLE bios (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    text TEXT NOT NULL
);

CREATE TABLE posts (
    post_id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    text TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE comments (
    comment_id SERIAL PRIMARY KEY,
    post_id INT NOT NULL REFERENCES posts(post_id) ON DELETE CASCADE,
    user_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    text TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE sessions (
    id TEXT PRIMARY KEY,
    user_id INT NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    CONSTRAINT sessions_user_id_users_user_id_fk FOREIGN KEY (user_id) REFERENCES users(user_id)
);

CREATE TABLE follows (
    follower_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    following_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (follower_id, following_id)
);

CREATE TABLE likes (
    post_id INT NOT NULL REFERENCES posts(post_id) ON DELETE CASCADE,
    comment_id INT REFERENCES comments(comment_id) ON DELETE CASCADE,
    user_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    is_post BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT likes_user_id_post_id_comment_id_is_post_unique UNIQUE (user_id, post_id, comment_id, is_post)
);

CREATE TABLE images (
    image_id SERIAL PRIMARY KEY,
    post_id INT NOT NULL,
    height INT NOT NULL,
    width INT NOT NULL,
    image_blob_url TEXT NOT NULL,
    display_order INT NOT NULL DEFAULT 0
);

CREATE TABLE notifications (
    notification_id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    post_id INT REFERENCES posts(post_id) ON DELETE CASCADE,
    comment_id INT REFERENCES comments(comment_id) ON DELETE CASCADE,
    message TEXT NOT NULL,
    link TEXT,
    viewed BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE "verificationCodes" (
    id SERIAL PRIMARY KEY,
    code TEXT NOT NULL,
    user_id INT NOT NULL UNIQUE,
    expires_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE device_token (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    token TEXT NOT NULL UNIQUE,
    is_enabled_mentions BOOLEAN NOT NULL DEFAULT TRUE,
    is_enabled_comments BOOLEAN NOT NULL DEFAULT TRUE,
    is_enabled_follows BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
