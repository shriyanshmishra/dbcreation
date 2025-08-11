-- DROP FUNCTION production.fetch_all_privilege_meta(jsonb);

CREATE OR REPLACE FUNCTION production.fetch_all_privilege_meta(json_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    current_user_id varchar(22);
    result jsonb := '[]'::jsonb;
BEGIN
    -- Step 1: Validate required JSON keys
    IF NOT (json_input ? 'data_space' AND json_input ? 'active_session') THEN
        RETURN production.get_response_message(
            jsonb_build_object(
                'data', jsonb_build_array(jsonb_build_object('error_code', '1001')),
                'active_session', json_input->'active_session'
            )
        );
    END IF;

    -- Step 2: Validate session token
    SELECT user_id INTO current_user_id
    FROM production.login_session_meta
    WHERE session_token = json_input->'active_session'->>'session_token'
      AND is_active = TRUE;

    IF current_user_id IS NULL THEN
        RETURN production.get_response_message(
            jsonb_build_object(
                'data', jsonb_build_array(jsonb_build_object('error_code', '1003')),
                'active_session', json_input->'active_session'
            )
        );
    END IF;

    -- Step 3: Fetch privilege list
    SELECT jsonb_agg(
        jsonb_build_object(
            'privilege_id', privilege_id,
            'Label', label,
            'Developer Name', developer_name,
            'Privilege Code', privilege_code,
            'Description', UPPER(COALESCE(description, ''))
        ) ORDER BY created_date
    )
    INTO result
    FROM production.privilege_meta;

    -- Step 4: Return the result
   RETURN COALESCE(result, '[]'::jsonb);
END;
$function$
;
