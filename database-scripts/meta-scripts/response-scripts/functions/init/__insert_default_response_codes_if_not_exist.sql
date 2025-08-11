CREATE OR REPLACE FUNCTION production.insert_default_response_codes_if_not_exist(
    user_id VARCHAR(22)
)
RETURNS VOID AS $$
BEGIN
    -- ERROR LOGIN_INVALID_EMAIL
    IF NOT EXISTS (
        SELECT 1 FROM production.response_codes WHERE response_code = 'LOGIN_INVALID_EMAIL'
    ) THEN
        INSERT INTO production.response_codes (
            code, response_type, created_by, last_modified_by
        ) VALUES (
            'LOGIN_INVALID_EMAIL', 'ERROR', user_id, user_id
        );

        INSERT INTO production.response_messages (
            code, locale, response_message, is_default, created_by, last_modified_by
        ) VALUES (
             'LOGIN_INVALID_EMAIL', 'en_us', 'Invalid Email Address : %s', true, user_id, user_id
         );
    END IF;

    -- ERROR LOGIN_EMAIL_DOES_NOT_EXIST
    IF NOT EXISTS (
        SELECT 1 FROM production.response_codes WHERE response_code = 'LOGIN_EMAIL_DOES_NOT_EXIST'
    ) THEN
        INSERT INTO production.response_codes (
            code, response_type, created_by, last_modified_by
        ) VALUES (
            'LOGIN_EMAIL_DOES_NOT_EXIST', 'ERROR', user_id, user_id
        );

        INSERT INTO production.response_messages (
            code, locale, response_message, is_default, created_by, last_modified_by
        ) VALUES (
             'LOGIN_EMAIL_DOES_NOT_EXIST', 'en_us', 'Email %s does not exists!', true, user_id, user_id
         );
    END IF;


    -- ERROR LOGIN_OTP_GENERATION_FAILED
    IF NOT EXISTS (
        SELECT 1 FROM production.response_codes WHERE response_code = 'LOGIN_OTP_GENERATION_FAILED'
    ) THEN
        INSERT INTO production.response_codes (
            code, response_type, created_by, last_modified_by
        ) VALUES (
            'LOGIN_OTP_GENERATION_FAILED', 'ERROR', user_id, user_id
        );

        INSERT INTO production.response_messages (
            code, locale, response_message, is_default, created_by, last_modified_by
        ) VALUES (
             'LOGIN_OTP_GENERATION_FAILED', 'en_us', 'Email %s does not exists!', true, user_id, user_id
         );
    END IF;

    -- ERROR LOGIN_OTP_EMAIL_SENT_FAILED
    IF NOT EXISTS (
        SELECT 1 FROM production.response_codes WHERE response_code = 'LOGIN_OTP_EMAIL_SENT_FAILED'
    ) THEN
        INSERT INTO production.response_codes (
            code, response_type, created_by, last_modified_by
        ) VALUES (
            'LOGIN_OTP_EMAIL_SENT_FAILED', 'ERROR', user_id, user_id
        );

    INSERT INTO production.response_messages (
        code, locale, response_message, is_default, created_by, last_modified_by
    ) VALUES (
         'LOGIN_OTP_EMAIL_SENT_FAILED', 'en_us', 'Email sent failed!', true, user_id, user_id
     );
    END IF;

    -- SUCCESS LOGIN_OTP_EMAIL_SENT
    IF NOT EXISTS (
        SELECT 1 FROM production.response_codes WHERE response_code = 'LOGIN_OTP_EMAIL_SENT'
    ) THEN
        INSERT INTO production.response_codes (
            code, response_type, created_by, last_modified_by
        ) VALUES (
            'LOGIN_OTP_EMAIL_SENT', 'SUCCESS', user_id, user_id
        );
        INSERT INTO production.response_messages (
            code, locale, response_message, is_default, created_by, last_modified_by
        ) VALUES (
             'LOGIN_OTP_EMAIL_SENT', 'en_us', 'Email sent successfully on %s!', true, user_id, user_id
         );
    END IF;
END;
$$ LANGUAGE plpgsql;