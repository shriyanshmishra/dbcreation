-- DROP FUNCTION production.create_role(jsonb);

CREATE OR REPLACE FUNCTION production.create_role(json_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    current_user_id TEXT;
    data_space TEXT := json_input ->> 'data_space';
    input_session_token TEXT := json_input->'active_session'->>'session_token';
    role_data jsonb;
    
    new_developer_name TEXT;
    created_by_user_id TEXT;
    reports_to_id TEXT;
    existing_role_label TEXT;
    input_existing_role_id TEXT;

    access_own_only BOOLEAN := FALSE;
    view_related BOOLEAN := FALSE;
    modify_related BOOLEAN := FALSE;

    new_role_id TEXT;
    view_name TEXT;

BEGIN
    -- Step 1 : Validate JSON structure
    IF NOT (json_input ? 'data_space' AND json_input ? 'active_session' AND json_input ? 'data') THEN
        RETURN production.get_response_message(
            jsonb_build_object(
                'data', jsonb_build_array(jsonb_build_object('error_code', '1001')),
                'active_session', json_input->'active_session'
            )
        );
    END IF;
    RAISE NOTICE 'Step1 Completed';

    -- Step 2 : Ensure data is an array
    IF jsonb_typeof(json_input->'data') <> 'array' THEN
        RETURN production.get_response_message(
            jsonb_build_object(
                'data', jsonb_build_array(jsonb_build_object('error_code', '1002')),
                'active_session', json_input->'active_session'
            )
        );
    END IF;
    RAISE NOTICE 'Step2 Completed';

    -- Step 3 : Validate session
    SELECT user_id INTO current_user_id
    FROM production.login_session_meta
    WHERE session_token = input_session_token;

    IF current_user_id IS NULL THEN
        RETURN production.get_response_message(
            jsonb_build_object(
                'data', jsonb_build_array(jsonb_build_object('error_code', '1003')),
                'active_session', json_input->'active_session'
            )
        );
    END IF;

    -- Step 4 : Check if schema exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.schemata 
        WHERE schema_name = data_space
    ) THEN
        RETURN production.get_response_message(
            jsonb_build_object(
                'data', jsonb_build_array(jsonb_build_object('error_code', '1005')),
                'active_session', json_input->'active_session'
            )
        );
    END IF;
    RAISE NOTICE 'Step3 Completed';

    -- Step 5 : Loop over data array
    FOR role_data IN SELECT * FROM jsonb_array_elements(json_input->'data') LOOP
        RAISE NOTICE 'Processing role data';

        new_developer_name := role_data ->> 'developer_name';
        reports_to_id := role_data ->> 'reports_to';
        existing_role_label := role_data ->> 'existing_role_label';
        input_existing_role_id := role_data ->> 'existing_role_id';
        created_by_user_id := current_user_id;

        -- Step 6 : Inherit permissions if existing_role_id provided
        IF input_existing_role_id IS NOT NULL THEN
            SELECT 
                rm.access_only_own_opportunity_records,
                rm.view_all_opportunity_records_related_to_account,
                rm.modify_all_opportunity_records_related_to_account
            INTO 
                access_own_only, view_related, modify_related
            FROM production.role_meta rm
            WHERE rm.role_id = input_existing_role_id;

            IF NOT FOUND THEN
                RETURN production.get_response_message(
                    jsonb_build_object(
                        'data', jsonb_build_array(jsonb_build_object(
                            'error_code', '1006',
                            'message', 'Referenced existing role not found'
                        )),
                        'active_session', json_input->'active_session'
                    )
                );
            END IF;
        END IF;

        -- Step 7 : Insert new role
        INSERT INTO production.role_meta (
            developer_name,
            reports_to,
            access_only_own_opportunity_records,
            view_all_opportunity_records_related_to_account,
            modify_all_opportunity_records_related_to_account,
            created_by, last_modified_by,
            existing_role_id, existing_role_label
        )
        VALUES (
            new_developer_name,
            reports_to_id,
            access_own_only, view_related, modify_related,
            created_by_user_id, created_by_user_id,
            input_existing_role_id, existing_role_label
        )
        RETURNING role_id INTO new_role_id;

        -- Step 8 : Create role-specific view
        view_name := format('view_role_%s', replace(lower(new_developer_name), ' ', '_'));

        EXECUTE format($sql$
            CREATE OR REPLACE VIEW production.%I AS
            SELECT * FROM production.role_meta
            WHERE developer_name = %L;
        $sql$, view_name, new_developer_name);

        -- ✅ Step 9: Return only the role_id
        RETURN jsonb_build_object('role_id', new_role_id);
    END LOOP;

    -- If loop doesn't run
    RETURN production.get_response_message(
        jsonb_build_object(
            'data', jsonb_build_array(jsonb_build_object(
                'error_code', '1007',
                'message', 'No valid role object found'
            )),
            'active_session', json_input->'active_session'
        )
    );
END;
$function$
;
