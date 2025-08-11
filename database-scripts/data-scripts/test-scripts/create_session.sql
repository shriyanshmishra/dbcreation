DO $$
DECLARE
    current_user_id varchar(22);
BEGIN
    -- Getting a user_id from the user table
    SELECT user_id INTO current_user_id
    FROM production.user 
    LIMIT 1;

    -- Inserting a new record into the login_session_meta table
    INSERT INTO production.login_session_meta (
        user_id,
        login_provider,
        session_token,
        ip_address,
        user_agent,
        session_end,
        is_active
    )
    VALUES (
        current_user_id,                             -- user_id (must exist in production.user)
        'local',                                            -- login_provider
        'Default-session-for-testing',                          -- session_token (should be securely generated)
        '203.0.113.42',                                     -- ip_address
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',         -- user_agent
        NULL,                                               -- session_end
        true                                                -- is_active
    );
END $$;
