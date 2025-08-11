CREATE OR REPLACE FUNCTION production.delete_entity_schema_and_share_table_function(json_input JSONB)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    current_user_id varchar(22);
    target_entity_id varchar(22);
    target_entity_share_id varchar(22);
    target_entity_dev_name text;
    target_entity_share_dev_name text;
    current_user_permissions jsonb;
    has_permission_to_delete boolean := false;
    entity_permission jsonb;
BEGIN
    -- Step 1 : Validate JSON structure
    IF NOT (json_input ? 'data_space' AND json_input ? 'active_session' AND json_input ? 'data') THEN
        --RAISE EXCEPTION 'Missing required top-level keys!';
        RETURN jsonb_build_object('error_code', '1001');  -- Missing required top-level keys
    END IF;
    RAISE NOTICE 'Step1 Completed';

    -- Step 2 : Ensure `data` is an array
    IF jsonb_typeof(json_input->'data') <> 'array' THEN
        --RAISE EXCEPTION 'The "data" field must be an array!';
        RETURN jsonb_build_object('error_code', '1002');  -- The "data" field must be an array!
    END IF;
    RAISE NOTICE 'Step2 Completed';

    -- Step 3 : Get user_id from the active session
    SELECT user_id INTO current_user_id
    FROM production.login_session_meta
    WHERE session_token = json_input->'active_session'->>'session_token';

    IF current_user_id IS NULL THEN
        --RAISE NOTICE 'User ID not found for the given session token!';
        RETURN jsonb_build_object('error_code', '1003');  -- Invalid session token
    END IF;

    -- Step  4 : Fetch user access JSON
    SELECT user_permissions INTO current_user_permissions
    FROM production.user_access_json_view
    WHERE user_id = current_user_id;

    -- Step 5: Loop through the data array and check entity permissions
    FOR entity_permission IN
        SELECT * FROM jsonb_array_elements(json_input->'data') -- Loop through the "data" array
    LOOP
        -- Extract the entity_id from the current entity in the data array
        target_entity_id := entity_permission->>'entity_id';
        
        -- RAISE NOTICE for debugging (can be removed later)
        RAISE NOTICE 'Checking permissions for entity_id: %', target_entity_id;

        -- Loop through entity_permissions to check if user has delete permission
        FOR entity_permission IN
            SELECT * FROM jsonb_array_elements(current_user_permissions->'entity_permissions')
        LOOP
            RAISE NOTICE 'entity_permission->>entity_id : % , entity_permission->>access_level : % ', entity_permission->>'entity_id', entity_permission->>'access_level';
            
            -- Check if the current user has delete access for the target entity
            IF (entity_permission->>'entity_id')::text = target_entity_id 
			   AND (entity_permission->>'access_level')::int IN (2, 8, 16, 32) THEN
			    has_permission_to_delete := true;
			    EXIT;  -- Exit once we find the permission
			END IF;

        END LOOP;
    END LOOP;

    -- If the user doesn't have permission, return an error
    IF NOT has_permission_to_delete THEN
        RETURN jsonb_build_object('error_code', '1203', 'message', 'User does not have permission to delete this entity');
    END IF;

    -- Step 6: Proceed to delete the entity and share table (assuming permission is granted)
    -- Get entity developer name (from target entity metadata)
    SELECT developer_name INTO target_entity_dev_name
    FROM production.entity_meta
    WHERE entity_id = target_entity_id;

    target_entity_share_dev_name := target_entity_dev_name || '_share';

    -- Get share table developer name (assuming the share table follows a naming convention)
    SELECT entity_id INTO target_entity_share_id
    FROM production.entity_meta
    WHERE developer_name = target_entity_share_dev_name;

    -- Drop the entity data table
    EXECUTE format('DROP TABLE IF EXISTS production.%I CASCADE', target_entity_dev_name);

    -- Drop the share table
    EXECUTE format('DROP TABLE IF EXISTS production.%I CASCADE', target_entity_share_dev_name);

	-- Deleting the entries from the database
	DELETE FROM production.entity_meta
	WHERE entity_id IN (target_entity_id, target_entity_share_id);

    RETURN jsonb_build_object('error_code', '0', 'message', 'Entity and its share table deleted');
END;
$$;