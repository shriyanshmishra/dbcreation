-- DROP FUNCTION production.create_tab_function(jsonb);

CREATE OR REPLACE FUNCTION production.create_tab_function(input_json jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_data                  jsonb;
    v_label                 text;
    v_dev_name              text;
    v_entity_id             text;
    v_app_ids               text[];
    v_privilege_set_ids     text[];
    v_privilege_ids         text[];
    v_description           text;
    v_is_restricted         boolean := false;

    v_data_space            text;
    v_meta_table            text;
    v_active_session        text;
    v_user_id               text;

    v_tab_key               int;
    v_tab_id                text;
    v_exists                int;
    v_icon_base64           text;
    v_icon_bytea            bytea;
    v_app_id                text;
    v_privilege_set_id      text;
    v_privilege_id          text;
BEGIN
    -- Step 1: Extract and validate input
    v_data_space     := input_json ->> 'data_space';
    v_meta_table     := input_json ->> 'meta_table';
    v_active_session := input_json -> 'active_session' ->> 'session_token';
    v_data           := input_json -> 'data' -> 0;

    -- Validate meta_table
    IF v_meta_table IS NULL OR v_meta_table <> 'tab_meta' THEN
        RETURN production.get_response_message('{"data":[{"error_code":"1706"}]}');
    END IF;

    IF v_data IS NULL THEN
        RETURN production.get_response_message('{"data":[{"error_code":"1700"}]}');
    END IF;

    -- Step 2: Decode tab_style icon
    v_icon_base64 := v_data ->> 'tab_style';
    IF v_icon_base64 IS NOT NULL AND v_icon_base64 <> '' THEN
        BEGIN
            v_icon_bytea := decode(v_icon_base64, 'base64');
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Invalid base64 in tab_style: %', SQLERRM;
        END;
    END IF;

    -- Step 3: Authenticate session
    SELECT user_id
      INTO v_user_id
      FROM production.login_session_meta
     WHERE session_token = v_active_session
       AND is_active     = true;

    IF v_user_id IS NULL THEN
        RETURN production.get_response_message('{"data":[{"error_code":"1003"}]}');
    END IF;

    -- Step 4: Extract fields (with fallbacks)
    v_label         := NULLIF(trim(v_data ->> 'label'), '');
    v_dev_name      := NULLIF(trim(v_data ->> 'developer_name'), '');
    v_entity_id     := v_data ->> 'entity_id';
    v_description   := v_data ->> 'description';
    v_is_restricted := COALESCE((v_data ->> 'is_restricted')::boolean, false);

    SELECT array_agg(x)
      INTO v_app_ids
      FROM jsonb_array_elements_text(COALESCE(v_data->'app_ids','[]')) AS x;

    SELECT array_agg(x)
      INTO v_privilege_set_ids
      FROM jsonb_array_elements_text(COALESCE(v_data->'privilege_set_ids','[]')) AS x;

    SELECT array_agg(x)
      INTO v_privilege_ids
      FROM jsonb_array_elements_text(COALESCE(v_data->'privilege_ids','[]')) AS x;

    -- Fallback: load label from entity_meta if not provided
    IF v_label IS NULL THEN
        SELECT label
          INTO v_label
          FROM production.entity_meta
         WHERE entity_id = v_entity_id;
    END IF;

    -- Fallback: derive developer_name if still missing
    IF v_dev_name IS NULL AND v_label IS NOT NULL THEN
        v_dev_name := replace(lower(v_label), ' ', '_') || '__tab';
    END IF;

    -- Validate required fields now
    IF v_label IS NULL OR v_dev_name IS NULL OR v_entity_id IS NULL THEN
        RETURN production.get_response_message('{"data":[{"error_code":"1700"}]}');
    END IF;

    -- Validate entity exists
    SELECT COUNT(*) INTO v_exists
      FROM production.entity_meta
     WHERE entity_id = v_entity_id;
    IF v_exists = 0 THEN
        RETURN production.get_response_message('{"data":[{"error_code":"1703"}]}');
    END IF;

    -- Validate app_ids if any
    IF v_app_ids IS NOT NULL THEN
        SELECT COUNT(*) INTO v_exists
          FROM unnest(v_app_ids) AS a
         WHERE NOT EXISTS (
               SELECT 1
                 FROM production.app_meta
                WHERE app_id = a
             );
        IF v_exists > 0 THEN
            RETURN production.get_response_message('{"data":[{"error_code":"1704"}]}');
        END IF;
    END IF;

    -- Step 5: Insert into tab_meta
    INSERT INTO production.tab_meta (
        label,
        developer_name,
        entity_id,
        description,
        tab_style,
        is_restricted,
        created_by,
        last_modified_by
    )
    VALUES (
        v_label,
        v_dev_name,
        v_entity_id,
        v_description,
        v_icon_bytea,
        v_is_restricted,
        v_user_id,
        v_user_id
    )
    RETURNING tab_key
      INTO v_tab_key;

    -- Generate the tab_id
    v_tab_id := 'TAB' || lpad(v_tab_key::text, 19, '0');

    -- Step 6: Insert into tab_app_link
    IF v_app_ids IS NOT NULL THEN
        FOREACH v_app_id IN ARRAY v_app_ids LOOP
            INSERT INTO production.tab_app_link (
                tab_id,
                app_id,
                sort_order,
                is_active,
                created_by,
                last_modified_by
            ) VALUES (
                v_tab_id,
                v_app_id,
                0,
                true,
                v_user_id,
                v_user_id
            );
        END LOOP;
    END IF;

    -- Step 7a: privilege_set_ids
    IF v_privilege_set_ids IS NOT NULL THEN
        FOREACH v_privilege_set_id IN ARRAY v_privilege_set_ids LOOP
            INSERT INTO production.tab_privilege_link (
                tab_id,
                privilege_set_id,
                is_active,
                created_by,
                last_modified_by
            ) VALUES (
                v_tab_id,
                v_privilege_set_id,
                true,
                v_user_id,
                v_user_id
            );
        END LOOP;
    END IF;

    -- Step 7b: privilege_ids
    IF v_privilege_ids IS NOT NULL THEN
        FOREACH v_privilege_id IN ARRAY v_privilege_ids LOOP
            INSERT INTO production.tab_privilege_link (
                tab_id,
                privilege_id,
                is_active,
                created_by,
                last_modified_by
            ) VALUES (
                v_tab_id,
                v_privilege_id,
                true,
                v_user_id,
                v_user_id
            );
        END LOOP;
    END IF;

    -- Step 8: Return success
    RETURN production.get_response_message(
        jsonb_build_object(
            'data',           jsonb_build_array(jsonb_build_object('success_code','2010')),
            'active_session', input_json->'active_session'
        )
    );

EXCEPTION
    WHEN unique_violation THEN
        IF SQLERRM LIKE '%tab_meta_devname_unique%' THEN
            RETURN production.get_response_message('{"data":[{"error_code":"1702"}]}');
        END IF;
        RETURN production.get_response_message('{"data":[{"error_code":"1705"}]}');

    WHEN OTHERS THEN
        RAISE NOTICE 'UNEXPECTED ERROR: %', SQLERRM;
        RETURN production.get_response_message('{"data":[{"error_code":"1705"}]}');
END;
$function$
;
