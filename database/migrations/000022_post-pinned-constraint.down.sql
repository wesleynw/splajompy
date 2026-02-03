ALTER TABLE users ADD CONSTRAINT users_pinned_post_id_fkey
    FOREIGN KEY (pinned_post_id) REFERENCES posts(post_id) ON DELETE SET NULL;
