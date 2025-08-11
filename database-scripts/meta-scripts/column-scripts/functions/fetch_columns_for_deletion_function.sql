CREATE OR REPLACE FUNCTION production.fetch_columns_for_deletion_function(json_input JSONB)
RETURNS JSONB AS $$
DECLARE
    current_user_id VARCHAR(22);
    current_user_permissions JSONB;
    target_column_id VARCHAR(22);
    current_entity_id VARCHAR(22);
    current_column_dev_name TEXT;
    current_entity_dev_name TEXT;
    first_entity_id VARCHAR(22);
    deletable_columns JSONB := '[]'::JSONB;
    has_permission_to_delete BOOLEAN := false;
    column_permission JSONB;
    entity_permission JSONB;
	result_json jsonb;
BEGIN
    -- Step 1: Validate JSON structure
    IF NOT (json_input ? 'data_space' AND json_input ? 'active_session' AND json_input ? 'data') THEN
        RETURN jsonb_build_object('error_code', '1001');  -- Missing required top-level keys
    END IF;

    -- Step 2: Ensure `data` is an array
    IF jsonb_typeof(json_input->'data') <> 'array' THEN
        RETURN jsonb_build_object('error_code', '1002');  -- The "data" field must be an array!
    END IF;

    -- Step 3: Get user_id from the active session
    SELECT user_id INTO current_user_id
    FROM production.login_session_meta
    WHERE session_token = json_input->'active_session'->>'session_token';

    IF current_user_id IS NULL THEN
        RETURN jsonb_build_object('error_code', '1003');  -- Invalid session token
    END IF;

    -- Step 4: Fetch user access JSON
    SELECT user_permissions INTO current_user_permissions
    FROM production.user_access_json_view
    WHERE user_id = current_user_id;

    -- Step 5: Loop through the data array and check permissions for each column
    FOR target_column_id IN
        SELECT (item->>'column_id')::TEXT FROM jsonb_array_elements(json_input->'data') AS item
    LOOP
        -- Reset permission flag for each column
        has_permission_to_delete := false;

        -- Get entity_id and developer_name of the column
        SELECT cm.entity_id, cm.developer_name
        INTO current_entity_id, current_column_dev_name
        FROM production.column_meta cm
        WHERE cm.column_id = target_column_id;

        -- Store the first entity_id for consistency check
        IF first_entity_id IS NULL THEN
            first_entity_id := current_entity_id;
        ELSIF current_entity_id <> first_entity_id THEN
            RETURN jsonb_build_object('error_code', '1204', 'message', 'Columns belong to different entities');
        END IF;

        -- === PERMISSION CHECK ===
        FOR column_permission IN
            SELECT * FROM jsonb_array_elements(current_user_permissions->'column_permissions')
        LOOP
            IF (column_permission->>'entity_id')::text = current_entity_id THEN
                FOR entity_permission IN
                    SELECT * FROM jsonb_array_elements(current_user_permissions->'entity_permissions')
                LOOP
                    IF (entity_permission->>'entity_id')::text = current_entity_id THEN
                        IF (entity_permission->>'access_level')::int IN (2, 8, 16, 32) THEN
                            has_permission_to_delete := true;
                            EXIT;  -- Exit inner loop
                        END IF;
                    END IF;
                END LOOP;
                EXIT;  -- Exit outer loop after entity match
            END IF;
        END LOOP;

        -- Append column details to deletable_columns array
        IF has_permission_to_delete THEN
            deletable_columns := deletable_columns || jsonb_build_object(
                'column_id', target_column_id,
                'developer_name', current_column_dev_name
            );
        END IF;
    END LOOP;

	result_json := jsonb_build_object(
        'data_space', json_input->>'data_space',
        'entity_id', first_entity_id,
        'data', deletable_columns
    );
	
	PERFORM production.update_views_before_column_deletion_function(result_json::jsonb);

    RETURN jsonb_build_object(
        'data_space', json_input->>'data_space',
        'entity_id', first_entity_id,
        'data', deletable_columns
    );
END;
$$ LANGUAGE plpgsql;