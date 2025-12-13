CREATE TABLE wrapped (
    user_id INT PRIMARY KEY NOT NULL,
    content JSON NOT NULL,
    generated TIMESTAMP DEFAULT NOW(),

     FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);
