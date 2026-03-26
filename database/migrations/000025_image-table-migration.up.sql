CREATE TABLE post_images (
    post_id       INTEGER NOT NULL REFERENCES posts(post_id) ON DELETE CASCADE,
    image_id      INTEGER NOT NULL REFERENCES images(image_id) ON DELETE CASCADE,
    display_order INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (post_id, image_id)
);

CREATE TABLE comment_images (
    comment_id INTEGER NOT NULL REFERENCES comments(comment_id) ON DELETE CASCADE,
    image_id   INTEGER NOT NULL REFERENCES images(image_id) ON DELETE CASCADE,
    PRIMARY KEY (comment_id, image_id)
);

INSERT INTO post_images (post_id, image_id, display_order)
SELECT post_id, image_id, display_order
FROM images;

ALTER TABLE images DROP COLUMN post_id;
ALTER TABLE images DROP COLUMN display_order;
