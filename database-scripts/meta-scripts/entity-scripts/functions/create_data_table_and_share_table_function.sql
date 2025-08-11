-- DROP FUNCTION production.create_data_table_and_share_table_function(jsonb);

CREATE OR REPLACE FUNCTION production.create_data_table_and_share_table_function(json_input jsonb)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    item jsonb;
    current_user_id varchar(22);
    entry_exists boolean; 
    inserted_entity_id varchar(22);
    result_json json;
    prefix_text text;
 has_permission jsonb;
BEGIN
    -- Step 1 : Validate JSON structure
    IF NOT (json_input ? 'data_space' AND json_input ? 'active_session' AND json_input ? 'data') THEN
        RETURN production.get_response_message(jsonb_build_object('data', jsonb_build_array(jsonb_build_object('error_code', '1001')), 'active_session', json_input->'active_session')); -- Missing required top-level keys
    END IF;
    RAISE NOTICE 'Step1 Completed';

    -- Step 2 : Ensure data is an array
    IF jsonb_typeof(json_input->'data') <> 'array' THEN
        RETURN production.get_response_message(jsonb_build_object('data', jsonb_build_array(jsonb_build_object('error_code', '1002')), 'active_session', json_input->'active_session'));-- The "data" field must be an array!
    END IF;
    RAISE NOTICE 'Step2 Completed';

    -- Get user_id from the active session
    SELECT user_id INTO current_user_id
    FROM production.login_session_meta
    WHERE session_token = json_input->'active_session'->>'session_token';

    IF current_user_id IS NULL THEN
        RETURN production.get_response_message(jsonb_build_object('data', jsonb_build_array(jsonb_build_object('error_code', '1003')), 'active_session', json_input->'active_session'));
    END IF;
-- check for the permission
    -- Step 4 : Check for required permission
    SELECT production.check_user_has_privilege(jsonb_build_object(
        'data_space', json_input->>'data_space',
        'active_session', json_input->'active_session',
        'privilege_name', 'Manage Entities'
    )) INTO has_permission;

   IF NOT (has_permission->>'has_privilege')::boolean THEN
        RETURN production.get_response_message(jsonb_build_object(
            'data', jsonb_build_array(jsonb_build_object('error_code', '1903')),
            'active_session', json_input->'active_session'));
    END IF;

    -- Step 3 : Ensure schema exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.schemata 
        WHERE schema_name = json_input->>'data_space'
    ) THEN
        RETURN production.get_response_message(jsonb_build_object('data', jsonb_build_array(jsonb_build_object('error_code', '1005')), 'active_session', json_input->'active_session'));
    END IF;
    RAISE NOTICE 'Step3 Completed';

    -- Step 4 : Loop through each item in the data array
    FOR item IN SELECT * FROM jsonb_array_elements(json_input->'data') LOOP
        RAISE NOTICE 'Loop started';

        -- Step 4.1: Rule 1015 - Label is required
        IF item->>'label' IS NULL OR trim(item->>'label') = '' THEN
            RETURN production.get_response_message(
                jsonb_build_object(
                    'data', jsonb_build_array(jsonb_build_object('error_code', '1015')),
                    'active_session', json_input->'active_session'
                )
            );
        END IF;

        -- Step 4.2: Rule 1016 - Plural label is required
        IF item->>'plural_label' IS NULL OR trim(item->>'plural_label') = '' THEN
            RETURN production.get_response_message(
                jsonb_build_object(
                    'data', jsonb_build_array(jsonb_build_object('error_code', '1016')),
                    'active_session', json_input->'active_session'
                )
            );
        END IF;
 -- Step 4.2: Rule 1017 The Object Name field can only contain underscores and alphanumeric characters. It must be unique, begin with a letter, not include spaces, not end with an underscore, and not contain two consecutive underscores.
        IF item->>'plural_label' IS NULL OR trim(item->>'developer_name') = '' THEN
            RETURN production.get_response_message(
                jsonb_build_object(
                    'data', jsonb_build_array(jsonb_build_object('error_code', '1017')),
                    'active_session', json_input->'active_session'
                )
            );
        END IF;

        -- Step 4.3: Rule 1009 - Developer name must be unique
        EXECUTE format(
            'SELECT EXISTS (SELECT 1 FROM %I.%I WHERE developer_name = %L)', 
            json_input->>'data_space', json_input->>'meta_table', item->>'developer_name'
        ) INTO entry_exists;

        IF entry_exists THEN
            RETURN production.get_response_message(
                jsonb_build_object(
                    'data', jsonb_build_array(jsonb_build_object('error_code', '1009')),
                    'active_session', json_input->'active_session'
                )
            );
        END IF;

        -- Step 4.4: Prefix validations
        prefix_text := item->>'prefix';

        -- Rule 1011: Invalid characters
        IF prefix_text ~ '[^a-zA-Z0-9_-]' THEN
            RETURN production.get_response_message(jsonb_build_object('data', jsonb_build_array(jsonb_build_object('error_code', '1011')), 'active_session', json_input->'active_session'));
        END IF;

        -- Rule 1012: Length > 3
        IF length(prefix_text) > 3 THEN
            RETURN production.get_response_message(jsonb_build_object('data', jsonb_build_array(jsonb_build_object('error_code', '1012')), 'active_session', json_input->'active_session'));
        END IF;

        -- Rule 1013: Only underscores
        IF prefix_text ~ '^_+$' THEN
            RETURN production.get_response_message(jsonb_build_object('data', jsonb_build_array(jsonb_build_object('error_code', '1013')), 'active_session', json_input->'active_session'));
        END IF;

        -- Rule 1014: '---'
        IF prefix_text = '---' THEN
            RETURN production.get_response_message(jsonb_build_object('data', jsonb_build_array(jsonb_build_object('error_code', '1014')), 'active_session', json_input->'active_session'));
        END IF;

        -- Step 4.5: Rule 1010 - Prefix must be unique
        EXECUTE format(
            'SELECT EXISTS (SELECT 1 FROM %I.%I WHERE prefix = %L)', 
            json_input->>'data_space', json_input->>'meta_table', prefix_text
        ) INTO entry_exists;

        IF entry_exists THEN
            RETURN production.get_response_message(jsonb_build_object('data', jsonb_build_array(jsonb_build_object('error_code', '1010')), 'active_session', json_input->'active_session'));
        END IF;

        RAISE NOTICE 'Step5 Completed';

        -- Step 5 : Check if entity table already exists
        IF EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = json_input->>'data_space'
            AND table_name = item->>'developer_name'
        ) THEN
            RETURN production.get_response_message(jsonb_build_object('data', jsonb_build_array(jsonb_build_object('error_code', '1006')), 'active_session', json_input->'active_session'));
        END IF;
        RAISE NOTICE 'Step6 Completed';

        -- Step 6 : Create data table
        SELECT production.create_data_table_function(item::jsonb, json_input->>'data_space', json_input->>'meta_table', current_user_id, json_input->'active_session'->>'session_token') INTO inserted_entity_id;

        -- Step 7 : Create share table
        PERFORM production.create_entity_share_table_function(item::jsonb, json_input->>'data_space', json_input->>'meta_table', current_user_id);

        -- Step 8 : Create default view
        PERFORM production.create_data_table_and_share_table_default_view_function(item->>'plural_label', item->>'developer_name', json_input->>'data_space', json_input->'active_session'->>'session_token');
    END LOOP;

    -- Step 9 : Return success response
    RETURN production.get_response_message(
        jsonb_build_object(
            'data', jsonb_build_array(jsonb_build_object('response_code', '2006')),
            'active_session', json_input->'active_session'
        )
    ) || jsonb_build_object('entity_id', inserted_entity_id);
END;
$function$
;
