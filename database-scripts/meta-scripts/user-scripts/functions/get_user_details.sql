CREATE OR REPLACE FUNCTION production.get_user_details(p_user_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
v_full_name TEXT;
result      JSONB;
BEGIN
    -- 1. Presence check
    IF p_user_id IS NULL THEN
    RETURN jsonb_build_array(
                jsonb_build_object(
                'error_code', '1001',
                'Message',  'UserID is not provided'
                )
            );
    END IF;



    -- 2. Length check
    IF char_length(p_user_id) <> 22 THEN
    RETURN jsonb_build_array(
                jsonb_build_object(
                'error_code', '1110',
                'Message', 'UserID length should be 22 characters'
                )
            );
    END IF;

    -- 3. Prefix check
    IF LEFT(p_user_id, 3) <> 'USR' THEN
    RETURN jsonb_build_array(
            jsonb_build_object(
            'error_code', '1110',
            'Message', 'Prefix check failed'
            )
        );
    END IF;

    -- 4. Lookup user 
    SELECT first_name || ' ' || last_name
    INTO v_full_name
    FROM production."user"
    WHERE user_id = p_user_id;

    IF NOT FOUND THEN
    RETURN jsonb_build_array(
                jsonb_build_object(
                'error_code', '1100',
                'Message',  'Entity not found'
                )
            );
    END IF;

    RAISE NOTICE 'Username is %', v_full_name;

    -- 5. Success: return array with single { Id, Name } object
    RETURN jsonb_build_array(
            jsonb_build_object(
                'Id',   p_user_id,
                'Name', v_full_name
            )
            );  
END;
$$;
