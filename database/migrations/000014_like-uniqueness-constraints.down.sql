ALTER TABLE likes DROP CONSTRAINT IF EXISTS likes_user_id_post_id_comment_id_is_post_unique;
DROP INDEX IF EXISTS likes_post_unique;
DROP INDEX IF EXISTS likes_comment_unique;

DELETE FROM likes
WHERE ctid NOT IN (
    SELECT MIN(ctid)
    FROM likes
    GROUP BY user_id, post_id, comment_id, is_post
);

CREATE UNIQUE INDEX likes_post_unique
    ON likes (user_id, post_id)
    WHERE comment_id IS NULL AND is_post = true;

CREATE UNIQUE INDEX likes_comment_unique
    ON likes (user_id, comment_id)
    WHERE comment_id IS NOT NULL AND is_post = false;
