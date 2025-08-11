-- DROP FUNCTION production.assign_privileges_to_app(jsonb);

CREATE OR REPLACE FUNCTION production.assign_privileges_to_app(input_json jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_data_space TEXT;
    v_session_token TEXT;
    v_user_id TEXT;

    v_payload JSONB;
    v_app_id TEXT;
    v_privilege_ids TEXT[];
    v_privilege_set_ids TEXT[];
    v_id TEXT;

    v_exists BOOLEAN;
BEGIN
    -- 1. Validate top-level keys
    RAISE NOTICE 'Validating top-level structure...';
    IF NOT input_json ? 'data_space' OR
       NOT input_json ? 'active_session' OR
       NOT input_json ? 'data' THEN
        RAISE NOTICE 'Missing one or more top-level keys.';
        RETURN production.get_response_message('{"data":[{"code_key":"1001"}]}');
    END IF;

    v_data_space := input_json ->> 'data_space';
    v_session_token := input_json -> 'active_session' ->> 'session_token';

    RAISE NOTICE 'Extracted data_space: %, session_token: %', v_data_space, v_session_token;

    IF v_session_token IS NULL OR length(v_session_token) < 10 THEN
        RAISE NOTICE 'Invalid or missing session token.';
        RETURN production.get_response_message('{"data":[{"code_key":"1003"}]}');
    END IF;

    IF jsonb_typeof(input_json -> 'data') <> 'array' THEN
        RAISE NOTICE '"data" is not an array.';
        RETURN production.get_response_message('{"data":[{"code_key":"1002"}]}');
    END IF;

    -- 2. Extract main payload
    v_payload := input_json -> 'data' -> 0;
    v_app_id := v_payload ->> 'app_id';
    v_privilege_ids := COALESCE(ARRAY(SELECT jsonb_array_elements_text(v_payload -> 'privilege_ids')), '{}');
    v_privilege_set_ids := COALESCE(ARRAY(SELECT jsonb_array_elements_text(v_payload -> 'privilege_set_ids')), '{}');

    RAISE NOTICE 'App ID: %', v_app_id;
    RAISE NOTICE 'Privilege IDs: %', v_privilege_ids;
    RAISE NOTICE 'Privilege Set IDs: %', v_privilege_set_ids;

    IF v_app_id IS NULL OR (array_length(v_privilege_ids, 1) IS NULL AND array_length(v_privilege_set_ids, 1) IS NULL) THEN
        RAISE NOTICE 'Missing app_id or both privilege arrays are empty.';
        RETURN production.get_response_message('{"data":[{"code_key":"1704"}]}');
    END IF;

    -- 3. Resolve user from session token
    SELECT user_id INTO v_user_id
    FROM production.login_session_meta
    WHERE session_token = v_session_token AND is_active = TRUE;

    RAISE NOTICE 'Resolved user_id: %', v_user_id;

    IF v_user_id IS NULL THEN
        RAISE NOTICE 'Session not found or inactive.';
        RETURN production.get_response_message('{"data":[{"code_key":"1003"}]}');
    END IF;

    -- 4. Validate app_id
    SELECT EXISTS (
        SELECT 1 FROM production.app_meta WHERE app_id = v_app_id AND is_active = TRUE
    ) INTO v_exists;

    RAISE NOTICE 'App exists: %', v_exists;

    IF NOT v_exists THEN
        RAISE NOTICE 'App ID % is invalid or inactive.', v_app_id;
        RETURN production.get_response_message('{"data":[{"code_key":"1731"}]}');
    END IF;

    -- 5. Assign privilege_ids
    FOREACH v_id IN ARRAY v_privilege_ids LOOP
        RAISE NOTICE 'Processing privilege_id: %', v_id;

        SELECT EXISTS (
            SELECT 1 FROM production.privilege_meta WHERE privilege_id = v_id
        ) INTO v_exists;

        IF NOT v_exists THEN
            RAISE NOTICE 'Invalid privilege_id: %', v_id;
            RETURN production.get_response_message('{"data":[{"code_key":"1734"}]}');
        END IF;

        SELECT EXISTS (
            SELECT 1 FROM production.app_privilege_link
            WHERE app_id = v_app_id AND privilege_id = v_id
        ) INTO v_exists;

        IF v_exists THEN
            RAISE NOTICE 'Privilege_id % already linked. Skipping.', v_id;
            CONTINUE;
        END IF;

        RAISE NOTICE 'Inserting privilege_id % into app %', v_id, v_app_id;

        INSERT INTO production.app_privilege_link (
            app_id, privilege_id, privilege_set_id,
            created_by, last_modified_by,
            version_number, is_latest, is_active
        )
        VALUES (
            v_app_id, v_id, NULL,
            v_user_id, v_user_id,
            1, TRUE, TRUE
        );
    END LOOP;

    -- 6. Assign privilege_set_ids
    FOREACH v_id IN ARRAY v_privilege_set_ids LOOP
        RAISE NOTICE 'Processing privilege_set_id: %', v_id;

        SELECT EXISTS (
            SELECT 1 FROM production.privilege_set_meta WHERE privilege_set_id = v_id
        ) INTO v_exists;

        IF NOT v_exists THEN
            RAISE NOTICE 'Invalid privilege_set_id: %', v_id;
            RETURN production.get_response_message('{"data":[{"code_key":"1735"}]}');
        END IF;

        SELECT EXISTS (
            SELECT 1 FROM production.app_privilege_link
            WHERE app_id = v_app_id AND privilege_set_id = v_id
        ) INTO v_exists;

        IF v_exists THEN
            RAISE NOTICE 'Privilege_set_id % already linked. Skipping.', v_id;
            CONTINUE;
        END IF;

        RAISE NOTICE 'Inserting privilege_set_id % into app %', v_id, v_app_id;

        INSERT INTO production.app_privilege_link (
            app_id, privilege_id, privilege_set_id,
            created_by, last_modified_by,
            version_number, is_latest, is_active
        )
        VALUES (
            v_app_id, NULL, v_id,
            v_user_id, v_user_id,
            1, TRUE, TRUE
        );
    END LOOP;

    -- 7. Return success
    RAISE NOTICE 'Privilege assignment completed.';
    RETURN production.get_response_message('{"data":[{"code_key":"2016"}]}');

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'assign_privileges_to_app() error: %', SQLERRM;
        RETURN production.get_response_message('{"data":[{"code_key":"1740"}]}');
END;
$function$
;
