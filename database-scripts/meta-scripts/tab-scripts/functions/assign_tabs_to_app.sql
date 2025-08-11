-- DROP FUNCTION production.assign_tabs_to_app(jsonb);

CREATE OR REPLACE FUNCTION production.assign_tabs_to_app(input_json jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_data_space TEXT;
    v_session_token TEXT;
    v_user_id TEXT;

    v_payload JSONB;
    v_app_id TEXT;
    v_tab_ids TEXT[];
    v_tab_id TEXT;

    v_exists BOOLEAN;
BEGIN
    -- 1. Top-level key validation
    RAISE NOTICE 'Validating top-level keys...';
    IF NOT input_json ? 'data_space' OR
       NOT input_json ? 'active_session' OR
       NOT input_json ? 'data' THEN
        RETURN production.get_response_message('{"data":[{"code_key":"1001"}]}');
    END IF;

    v_data_space := input_json ->> 'data_space';
    v_session_token := input_json -> 'active_session' ->> 'session_token';

    RAISE NOTICE 'data_space: %, session_token: %', v_data_space, v_session_token;

    -- 2. Session validation
    IF v_session_token IS NULL OR length(v_session_token) < 10 THEN
        RAISE NOTICE 'Session token is invalid.';
        RETURN production.get_response_message('{"data":[{"code_key":"1003"}]}');
    END IF;

    IF jsonb_typeof(input_json -> 'data') <> 'array' THEN
        RAISE NOTICE '"data" is not an array.';
        RETURN production.get_response_message('{"data":[{"code_key":"1002"}]}');
    END IF;

    -- 3. Extract payload
    v_payload := input_json -> 'data' -> 0;
    v_app_id := v_payload ->> 'app_id';
    v_tab_ids := ARRAY(SELECT jsonb_array_elements_text(v_payload -> 'tab_ids'));

    RAISE NOTICE 'App ID: %, Tab IDs: %', v_app_id, v_tab_ids;

    IF v_app_id IS NULL OR array_length(v_tab_ids, 1) IS NULL THEN
        RAISE NOTICE 'Missing app_id or tab_ids.';
        RETURN production.get_response_message('{"data":[{"code_key":"1704"}]}');
    END IF;

    -- 4. Resolve session user
    SELECT user_id INTO v_user_id
    FROM production.login_session_meta
    WHERE session_token = v_session_token AND is_active = TRUE;

    RAISE NOTICE 'Resolved user_id: %', v_user_id;

    IF v_user_id IS NULL THEN
        RAISE NOTICE 'No user found for given session token.';
        RETURN production.get_response_message('{"data":[{"code_key":"1003"}]}');
    END IF;

    -- 5. Check app_id exists
    SELECT EXISTS (
        SELECT 1 FROM production.app_meta WHERE app_id = v_app_id AND is_active = TRUE
    ) INTO v_exists;

    RAISE NOTICE 'App ID exists: %', v_exists;

    IF NOT v_exists THEN
        RAISE NOTICE 'Invalid app_id: %', v_app_id;
        RETURN production.get_response_message('{"data":[{"code_key":"1731"}]}');
    END IF;

    -- 6. Validate each tab_id
    FOREACH v_tab_id IN ARRAY v_tab_ids LOOP
        RAISE NOTICE 'Processing tab_id: %', v_tab_id;

        SELECT EXISTS (
            SELECT 1 FROM production.tab_meta WHERE tab_id = v_tab_id
        ) INTO v_exists;

        IF NOT v_exists THEN
            RAISE NOTICE 'Tab ID not found: %', v_tab_id;
            RETURN production.get_response_message('{"data":[{"code_key":"1732"}]}');
        END IF;

        -- 7. Skip if already linked
        SELECT EXISTS (
            SELECT 1 FROM production.tab_app_link
            WHERE app_id = v_app_id AND tab_id = v_tab_id
        ) INTO v_exists;

        IF v_exists THEN
            RAISE NOTICE 'Tab already linked to app: %', v_tab_id;
            CONTINUE;
        END IF;

        -- 8. Insert new row
        RAISE NOTICE 'Inserting tab link for app: %, tab: %', v_app_id, v_tab_id;

        INSERT INTO production.tab_app_link (
            app_id, tab_id, sort_order,
            is_active, is_latest, version_number,
            created_by, last_modified_by
        )
        VALUES (
            v_app_id, v_tab_id, 0,
            TRUE, TRUE, 1,
            v_user_id, v_user_id
        );
    END LOOP;

    -- 9. Return success
    RAISE NOTICE 'Tab assignment completed successfully.';
    RETURN production.get_response_message('{"data":[{"code_key":"2015"}]}');

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'assign_tabs_to_app() error: %', SQLERRM;
        RETURN production.get_response_message('{"data":[{"code_key":"1740"}]}');
END;
$function$
;
