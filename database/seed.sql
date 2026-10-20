BEGIN;

INSERT INTO users (email, password, username, name, referral_code)
VALUES
    ('local_alice@example.test', '$2a$10$xN/jIw0JTU7lN7lHK3fuSOFmUlK.ZJUPPYhRgBfWSefndw3x74TuW', 'local_alice', 'Local Alice', 'LOCALALICE'),
    ('local_bob@example.test', '$2a$10$xN/jIw0JTU7lN7lHK3fuSOFmUlK.ZJUPPYhRgBfWSefndw3x74TuW', 'local_bob', 'Local Bob', 'LOCALBOB')
ON CONFLICT (username) DO NOTHING;

INSERT INTO posts (user_id, text)
SELECT user_id, 'A local test post from ' || username || '.'
FROM users u
WHERE username IN ('local_alice', 'local_bob')
    AND NOT EXISTS (SELECT 1 FROM posts WHERE user_id = u.user_id AND text = 'A local test post from ' || u.username || '.');

INSERT INTO comments (post_id, user_id, text)
SELECT p.post_id, bob.user_id, 'A local test comment.'
FROM posts p
JOIN users alice ON alice.user_id = p.user_id AND alice.username = 'local_alice'
JOIN users bob ON bob.username = 'local_bob'
WHERE p.text = 'A local test post from local_alice.'
    AND NOT EXISTS (SELECT 1 FROM comments WHERE post_id = p.post_id AND user_id = bob.user_id AND text = 'A local test comment.');

INSERT INTO follows (follower_id, following_id)
SELECT bob.user_id, alice.user_id FROM users bob, users alice
WHERE bob.username = 'local_bob' AND alice.username = 'local_alice'
ON CONFLICT DO NOTHING;

INSERT INTO likes (post_id, user_id)
SELECT p.post_id, bob.user_id
FROM posts p
JOIN users alice ON alice.user_id = p.user_id AND alice.username = 'local_alice'
JOIN users bob ON bob.username = 'local_bob'
WHERE p.text = 'A local test post from local_alice.'
ON CONFLICT DO NOTHING;

INSERT INTO notifications (user_id, target_user_id, message, notification_type, viewed)
SELECT alice.user_id, bob.user_id, fixture.message, 'announcement', fixture.viewed
FROM users alice, users bob, (VALUES ('An unread local test notification.', FALSE), ('A read local test notification.', TRUE)) AS fixture(message, viewed)
WHERE alice.username = 'local_alice' AND bob.username = 'local_bob'
    AND NOT EXISTS (SELECT 1 FROM notifications WHERE user_id = alice.user_id AND message = fixture.message);

COMMIT;
