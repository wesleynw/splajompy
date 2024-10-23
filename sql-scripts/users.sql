CREATE TABLE users (
    id SERIAL PRIMARY KEY,          
    email VARCHAR(255) NOT NULL UNIQUE, 
    password VARCHAR(255) NOT NULL,    
    username VARCHAR(100) NOT NULL UNIQUE 
);
