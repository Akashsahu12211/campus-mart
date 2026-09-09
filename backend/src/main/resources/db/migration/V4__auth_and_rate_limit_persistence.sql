CREATE TABLE IF NOT EXISTS refresh_token_sessions (
    id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    token_jti VARCHAR(64) NOT NULL,
    user_id BIGINT NOT NULL,
    email VARCHAR(255) NOT NULL,
    session_version INT NOT NULL DEFAULT 0,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_used_at DATETIME NULL,
    expires_at DATETIME NOT NULL,
    revoked_at DATETIME NULL,
    replaced_by_jti VARCHAR(64) NULL,
    CONSTRAINT uk_refresh_token_sessions_jti UNIQUE (token_jti),
    INDEX idx_refresh_token_user_id (user_id),
    INDEX idx_refresh_token_expires_at (expires_at),
    INDEX idx_refresh_token_revoked_at (revoked_at)
);

CREATE TABLE IF NOT EXISTS api_rate_limit_windows (
    id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    rate_key VARCHAR(160) NOT NULL,
    action_name VARCHAR(50) NOT NULL,
    window_minutes INT NOT NULL,
    limit_count INT NOT NULL,
    request_count INT NOT NULL,
    window_started_at DATETIME NOT NULL,
    expires_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_api_rate_limit_windows_key UNIQUE (rate_key),
    INDEX idx_rate_limit_expires_at (expires_at),
    INDEX idx_rate_limit_action (action_name)
);
