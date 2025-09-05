-- Schema extraído de: /home/cadu/projeto_SPR/spr_users.db
-- Data: 1754201209.0843017

CREATE INDEX idx_sessions_token ON user_sessions(token_hash);

CREATE INDEX idx_sessions_user ON user_sessions(user_id);

CREATE INDEX idx_users_email ON users(email);

CREATE INDEX idx_users_username ON users(username);

CREATE TABLE user_sessions (
                        id TEXT PRIMARY KEY,
                        user_id TEXT NOT NULL,
                        token_hash TEXT NOT NULL,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        expires_at TIMESTAMP NOT NULL,
                        is_active BOOLEAN DEFAULT 1,
                        FOREIGN KEY (user_id) REFERENCES users (id)
                    );

CREATE TABLE users (
                        id TEXT PRIMARY KEY,
                        username TEXT UNIQUE NOT NULL,
                        email TEXT UNIQUE NOT NULL,
                        password_hash TEXT NOT NULL,
                        roles TEXT NOT NULL,
                        is_active BOOLEAN DEFAULT 1,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        last_login TIMESTAMP,
                        failed_login_attempts INTEGER DEFAULT 0,
                        locked_until TIMESTAMP,
                        password_changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        email_verified BOOLEAN DEFAULT 0,
                        reset_token TEXT,
                        reset_token_expires TIMESTAMP,
                        profile_data TEXT DEFAULT '{}'
                    );

-- INFORMAÇÕES DAS TABELAS

-- Tabela: users
-- Registros: 4
-- Colunas:
--   id TEXT NULL PRIMARY KEY
--   username TEXT NOT NULL 
--   email TEXT NOT NULL 
--   password_hash TEXT NOT NULL 
--   roles TEXT NOT NULL 
--   is_active BOOLEAN NULL 
--   created_at TIMESTAMP NULL 
--   updated_at TIMESTAMP NULL 
--   last_login TIMESTAMP NULL 
--   failed_login_attempts INTEGER NULL 
--   locked_until TIMESTAMP NULL 
--   password_changed_at TIMESTAMP NULL 
--   email_verified BOOLEAN NULL 
--   reset_token TEXT NULL 
--   reset_token_expires TIMESTAMP NULL 
--   profile_data TEXT NULL 

-- Tabela: user_sessions
-- Registros: 6
-- Colunas:
--   id TEXT NULL PRIMARY KEY
--   user_id TEXT NOT NULL 
--   token_hash TEXT NOT NULL 
--   created_at TIMESTAMP NULL 
--   expires_at TIMESTAMP NOT NULL 
--   is_active BOOLEAN NULL 
