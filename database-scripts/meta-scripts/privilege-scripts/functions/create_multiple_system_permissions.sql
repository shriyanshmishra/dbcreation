-- DROP FUNCTION production.create_multiple_system_permissions(jsonb);

CREATE OR REPLACE FUNCTION production.create_multiple_system_permissions(input_json jsonb)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    current_user_id TEXT;
    v_session_token TEXT := input_json->'active_session'->>'session_token';
    v_perm jsonb;
    v_results jsonb := '[]'::jsonb;

    -- temp vars per permission
    v_permission_name text;
    v_description text;
    v_privilege_label text;
    v_privilege_dev_name text;
    v_privilege_code int;
    v_flag boolean;
    v_system_privilege_master_id varchar(22);
    v_privilege_id varchar(22);
    v_assignment_label text;
    v_assignment_dev_name text;

    -- privilege set support
    v_privilege_set_id varchar(22);

BEGIN
    -- Step 1 : Validate JSON structure
    IF NOT (input_json ? 'data_space' AND input_json ? 'active_session' AND input_json ? 'permissions') THEN
        RETURN production.get_response_message(jsonb_build_object(
            'data', jsonb_build_array(jsonb_build_object('error_code', '1001')),
            'active_session', input_json->'active_session'
        ));
    END IF;
    RAISE NOTICE 'Step1 Completed';

    -- Step 2 : Ensure data is an array
    IF jsonb_typeof(input_json->'permissions') <> 'array' THEN
        RETURN production.get_response_message(jsonb_build_object(
            'data', jsonb_build_array(jsonb_build_object('error_code', '1002')),
            'active_session', input_json->'active_session'
        ));
    END IF;
    RAISE NOTICE 'Step2 Completed';

    -- Step 3 : Validate session and user
    SELECT user_id INTO current_user_id
    FROM production.login_session_meta
    WHERE session_token = v_session_token AND is_active = true
    ORDER BY session_start DESC
    LIMIT 1;

    IF current_user_id IS NULL THEN
        RETURN production.get_response_message(jsonb_build_object(
            'data', jsonb_build_array(jsonb_build_object('error_code', '1003')),
            'active_session', input_json->'active_session'
        ));
    END IF;

    -- Step 4 : Ensure schema exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.schemata 
        WHERE schema_name = input_json->>'data_space'
    ) THEN
        RETURN production.get_response_message(jsonb_build_object(
            'data', jsonb_build_array(jsonb_build_object('error_code', '1005')),
            'active_session', input_json->'active_session'
        ));
    END IF;
    RAISE NOTICE 'Step3 Completed';

    -- Step 4.1 : Validate privilege_set_id if provided
    v_privilege_set_id := input_json->>'privilege_set_id';

    IF v_privilege_set_id IS NULL OR NOT EXISTS (
        SELECT 1 FROM production.privilege_set_meta WHERE privilege_set_id = v_privilege_set_id
    ) THEN
        RETURN production.get_response_message(jsonb_build_object(
            'data', jsonb_build_array(jsonb_build_object(
                'error_code', '1907',
                'error_message', 'Invalid privilege_set_id'
            )),
            'active_session', input_json->'active_session'
        ));
    END IF;

    -- Step 5: Loop through each permission
    FOR v_perm IN SELECT * FROM jsonb_array_elements(input_json->'permissions')
    LOOP
        -- extract each field
        v_permission_name := trim(v_perm->>'permission_name');
        v_description := v_perm->>'description';
        v_privilege_label := trim(v_perm->>'privilege_label');
        v_privilege_dev_name := trim(v_perm->>'privilege_dev_name');
        v_privilege_code := COALESCE((v_perm->>'privilege_code')::int, 0);
        v_flag := CASE 
                    WHEN lower(v_perm->>'flag') = 'true' THEN true
                    WHEN lower(v_perm->>'flag') = 'false' THEN false
                    ELSE NULL
                  END;

        -- Insert or update system_privilege_master_meta
        INSERT INTO production.system_privilege_master_meta (permission_name, description)
        VALUES (v_permission_name, v_description)
        ON CONFLICT (permission_name)
        DO UPDATE SET description = EXCLUDED.description
        RETURNING system_privilege_master_id INTO v_system_privilege_master_id;

        -- Insert or update privilege_meta
        INSERT INTO production.privilege_meta (
            label, developer_name, privilege_code, description, created_by, user_id
        )
        VALUES (
            v_privilege_label, v_privilege_dev_name, v_privilege_code,
            v_description, current_user_id, current_user_id
        )
        ON CONFLICT (developer_name)
        DO UPDATE SET
            privilege_code = EXCLUDED.privilege_code,
            description = EXCLUDED.description
        RETURNING privilege_id INTO v_privilege_id;

        -- Insert or ignore into system_privilege_meta
        INSERT INTO production.system_privilege_meta (
            privilege_id, system_privilege_master_id, flag, created_by
        )
        SELECT v_privilege_id, v_system_privilege_master_id, v_flag, current_user_id
        WHERE NOT EXISTS (
            SELECT 1
            FROM production.system_privilege_meta
            WHERE privilege_id = v_privilege_id 
              AND system_privilege_master_id = v_system_privilege_master_id
              AND (flag IS NOT DISTINCT FROM v_flag)
        );

        -- Insert into user_privilege_assignment
        v_assignment_label := v_permission_name || ' - ' || current_user_id;
        v_assignment_dev_name := lower(replace(v_assignment_label, ' ', '_'));

        INSERT INTO production.user_privilege_assignment (
            label, developer_name, privilege_id, user_id, created_by
        )
        SELECT v_assignment_label, v_assignment_dev_name, v_privilege_id, current_user_id, current_user_id
        WHERE NOT EXISTS (
            SELECT 1
            FROM production.user_privilege_assignment
            WHERE privilege_id = v_privilege_id AND user_id = current_user_id
        );

        -- Insert into privilege_set_mapping
        INSERT INTO production.privilege_set_mapping (
            privilege_set_id, privilege_id, created_by
        )
        SELECT v_privilege_set_id, v_privilege_id, current_user_id
        WHERE NOT EXISTS (
            SELECT 1 FROM production.privilege_set_mapping
            WHERE privilege_set_id = v_privilege_set_id AND privilege_id = v_privilege_id
        );

        -- Insert into privilege_set_assignment
        INSERT INTO production.privilege_set_assignment (
            privilege_set_id, user_id, assigned_by
        )
        SELECT v_privilege_set_id, current_user_id, current_user_id
        WHERE NOT EXISTS (
            SELECT 1 FROM production.privilege_set_assignment
            WHERE privilege_set_id = v_privilege_set_id AND user_id = current_user_id
        );

        -- Append result
        v_results := v_results || jsonb_build_object(
            'permission_name', v_permission_name,
            'privilege_id', v_privilege_id,
            'system_privilege_master_id', v_system_privilege_master_id,
            'status', 'created_or_updated'
        );
    END LOOP;

    RETURN json_build_object(
        'status', 'success',
        'user_id', current_user_id,
        'permissions_created', v_results
    );
END;
$function$;
