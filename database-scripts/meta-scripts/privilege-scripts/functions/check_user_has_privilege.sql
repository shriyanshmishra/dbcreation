-- DROP FUNCTION production.check_user_has_privilege(jsonb);

CREATE OR REPLACE FUNCTION production.check_user_has_privilege(input_json jsonb)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_data_space TEXT := input_json->>'data_space';
    v_session_token TEXT := input_json->'active_session'->>'session_token';
    v_user_id TEXT;
    v_privilege_label TEXT := trim(input_json->>'privilege_name');
    v_privilege_id TEXT;
    v_exists BOOLEAN := false;
BEGIN
    -- Step 1: Validate input
    IF NOT (input_json ? 'data_space' AND input_json ? 'active_session' AND input_json ? 'privilege_name') THEN
        RETURN production.get_response_message(jsonb_build_object(
            'data', jsonb_build_array(jsonb_build_object('error_code', '1001')),
            'active_session', input_json->'active_session'
        ));
    END IF;

    -- Step 2: Validate schema
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.schemata
        WHERE schema_name = v_data_space
    ) THEN
        RETURN production.get_response_message(jsonb_build_object(
            'data', jsonb_build_array(jsonb_build_object('error_code', '1005')),
            'active_session', input_json->'active_session'
        ));
    END IF;

    -- Step 3: Resolve user_id from session
    SELECT user_id INTO v_user_id
    FROM production.login_session_meta
    WHERE session_token = v_session_token AND is_active = true
    ORDER BY session_start DESC
    LIMIT 1;

    IF v_user_id IS NULL THEN
        RETURN production.get_response_message(jsonb_build_object(
            'data', jsonb_build_array(jsonb_build_object('error_code', '1003')),
            'active_session', input_json->'active_session'
        ));
    END IF;

    -- Step 4: Get privilege ID from privilege name
    SELECT privilege_id INTO v_privilege_id
    FROM production.privilege_meta
    WHERE label = v_privilege_label;

    IF v_privilege_id IS NULL THEN
        RETURN production.get_response_message(jsonb_build_object(
            'data', jsonb_build_array(jsonb_build_object('error_code', '1901')),
            'active_session', input_json->'active_session'
        ));
    END IF;

    -- Step 5.1: Check privilege via user permission set
    SELECT true INTO v_exists
    FROM (
        SELECT 1
        FROM production.privilege_set_assignment psa
        JOIN production.privilege_set_mapping psm 
          ON psa.privilege_set_id = psm.privilege_set_id
        WHERE psa.user_id = v_user_id
          AND psm.privilege_id = v_privilege_id
        LIMIT 1
    ) AS sub;

    IF v_exists THEN
        RETURN json_build_object(
            'status', 'success',
            'privilege_label', v_privilege_label,
            'privilege_id', v_privilege_id,
            'user_id', v_user_id,
            'has_privilege', true
        );
    END IF;

    -- Step 5.2: Check privilege via role-based permission set
    SELECT true INTO v_exists
    FROM (
        SELECT 1
        FROM production.user u
        JOIN production.privilege_set_assignment psa 
          ON psa.role_id = u.role_id
        JOIN production.privilege_set_mapping psm 
          ON psa.privilege_set_id = psm.privilege_set_id
        WHERE u.user_id = v_user_id
          AND psm.privilege_id = v_privilege_id
        LIMIT 1
    ) AS sub;

    IF v_exists THEN
        RETURN json_build_object(
            'status', 'success',
            'privilege_label', v_privilege_label,
            'privilege_id', v_privilege_id,
            'user_id', v_user_id,
            'has_privilege', true
        );
    END IF;

    -- Step 5.3: Check direct privilege assignment
    SELECT true INTO v_exists
    FROM (
        SELECT 1
        FROM production.user_privilege_assignment
        WHERE user_id = v_user_id
          AND privilege_id = v_privilege_id
        LIMIT 1
    ) AS sub;

    RETURN json_build_object(
        'status', 'success',
        'privilege_label', v_privilege_label,
        'privilege_id', v_privilege_id,
        'user_id', v_user_id,
        'has_privilege', COALESCE(v_exists, false)
    );
END;
$function$;
