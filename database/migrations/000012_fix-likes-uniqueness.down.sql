DROP INDEX IF EXISTS likes_post_unique;
DROP INDEX IF EXISTS likes_comment_unique;

ALTER TABLE likes ADD CONSTRAINT likes_user_id_post_id_comment_id_is_post_unique
    UNIQUE (user_id, post_id, comment_id, is_post);
