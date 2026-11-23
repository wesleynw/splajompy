CREATE INDEX CONCURRENTLY idx_post_likes_post_id ON likes (post_id) WHERE comment_id IS NULL;
