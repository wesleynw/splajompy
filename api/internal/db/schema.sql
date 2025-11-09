CREATE TABLE users (
    user_id integer NOT NULL,
    email character varying(255) NOT NULL,
    password character varying(255) NOT NULL,
    username character varying(100) NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    name text,
    is_verified boolean DEFAULT FALSE NOT NULL,
    pinned_post_id integer,
    user_display_properties jsonb NULL
);

CREATE TABLE bios (
    id SERIAL PRIMARY KEY NOT NULL,
    user_id INT NOT NULL,
    text TEXT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

CREATE TABLE posts (
    post_id SERIAL PRIMARY KEY NOT NULL,
    user_id INTEGER NOT NULL,
    text TEXT,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    facets JSON,
    attributes JSON,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

CREATE TABLE comments (
    comment_id SERIAL PRIMARY KEY NOT NULL,
    post_id INT NOT NULL,
    user_id INT NOT NULL,
    text TEXT NOT NULL,
    facets JSON,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    FOREIGN KEY (post_id) REFERENCES posts(post_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

CREATE TABLE sessions (
    id TEXT PRIMARY KEY NOT NULL,
    user_id INTEGER UNIQUE NOT NULL,
    expires_at TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

CREATE TABLE follows (
    follower_id INTEGER NOT NULL,
    following_id INTEGER NOT NULL,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    FOREIGN KEY (follower_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (following_id) REFERENCES users(user_id) ON DELETE CASCADE,
    UNIQUE (follower_id, following_id)
);

CREATE TABLE likes (
    post_id INT NOT NULL,
    comment_id INT NULL,
    user_id INT NOT NULL,
    FOREIGN KEY (post_id) REFERENCES posts(post_id) ON DELETE CASCADE,
    FOREIGN KEY (comment_id) REFERENCES comments(comment_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

CREATE TABLE images (
    image_id SERIAL PRIMARY KEY NOT NULL,
    post_id INT NOT NULL,
    height INT NOT NULL,
    width INT NOT NULL,
    image_blob_url TEXT NOT NULL,
    display_order INT NOT NULL DEFAULT 0
);

CREATE TABLE notifications (
    notification_id SERIAL PRIMARY KEY NOT NULL,
    user_id INT NOT NULL,
    post_id INT NULL,
    comment_id INT NULL,
    target_user_id INT NULL,
    message TEXT NOT NULL,
    link TEXT NULL,
    viewed BOOLEAN NOT NULL DEFAULT FALSE,
    facets JSON,
    notification_type VARCHAR(50) NOT NULL DEFAULT 'default',
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    FOREIGN KEY (post_id) REFERENCES posts(post_id) ON DELETE CASCADE,
    FOREIGN KEY (comment_id) REFERENCES comments(comment_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

CREATE TABLE "verificationCodes" ( -- TODO: rename this to fit the casing of other tables
    id SERIAL PRIMARY KEY NOT NULL,
    code TEXT NOT NULL,
    user_id INT UNIQUE NOT NULL,
    expires_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS block (
 id SERIAL PRIMARY KEY,
 user_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
target_user_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

CONSTRAINT unique_user_target_user_id_block UNIQUE(user_id, target_user_id),
CONSTRAINT check_no_self_block CHECK (user_id != target_user_id)
);

CREATE TABLE IF NOT EXISTS mute (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    target_user_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT unique_user_target_user_id_mute UNIQUE(user_id, target_user_id),
    CONSTRAINT check_no_self_mute CHECK (user_id != target_user_id)
);

CREATE TABLE IF NOT EXISTS poll_vote (
    id SERIAL PRIMARY KEY,
    post_id INT NOT NULL REFERENCES posts(post_id) ON DELETE CASCADE,
    user_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    option_index INT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(post_id, user_id)
);

ALTER TABLE users ADD CONSTRAINT fk_users_pinned_post FOREIGN KEY (pinned_post_id) REFERENCES posts(post_id) ON DELETE SET NULL;
