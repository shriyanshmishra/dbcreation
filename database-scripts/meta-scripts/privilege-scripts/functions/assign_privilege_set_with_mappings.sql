-- DROP FUNCTION production.assign_privilege_set_with_mappings(jsonb);

CREATE OR REPLACE FUNCTION production.assign_privilege_set_with_mappings(json_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    item jsonb;
    privilege_item jsonb;
    current_user_id varchar(22);
    response_array jsonb := '[]'::jsonb;
    v_privilege_set_id varchar(22);
    v_role_id varchar(22);
    v_user_id varchar(22);
BEGIN
    -- Validate base keys
    IF NOT (
        json_input ? 'data_space' AND 
        json_input ? 'active_session' AND 
        json_input ? 'data'
    ) THEN
        RETURN production.get_response_message(
            jsonb_build_object(
                'data', jsonb_build_array(jsonb_build_object('error_code', '1001')),
                'active_session', json_input->'active_session'
            )
        );
    END IF;

    -- Validate array
    IF jsonb_typeof(json_input->'data') <> 'array' THEN
        RETURN production.get_response_message(
            jsonb_build_object(
                'data', jsonb_build_array(jsonb_build_object('error_code', '1002')),
                'active_session', json_input->'active_session'
            )
        );
    END IF;

    -- Validate session and extract user
    SELECT user_id INTO current_user_id
    FROM production.login_session_meta
    WHERE session_token = json_input->'active_session'->>'session_token';

    IF current_user_id IS NULL THEN
        RETURN production.get_response_message(
            jsonb_build_object(
                'data', jsonb_build_array(jsonb_build_object('error_code', '1003')),
                'active_session', json_input->'active_session'
            )
        );
    END IF;

    -- Loop through input data
    FOR item IN SELECT * FROM jsonb_array_elements(json_input->'data')
    LOOP
        -- Extract and validate keys
        v_privilege_set_id := item->>'privilege_set_id';
        v_role_id := item->>'role_id';
        v_user_id := item->>'user_id';

        IF v_privilege_set_id IS NULL OR v_privilege_set_id = '' THEN
            RETURN production.get_response_message(
                jsonb_build_object(
                    'data', jsonb_build_array(jsonb_build_object('error_code', '1004', 'message', 'Missing privilege_set_id')),
                    'active_session', json_input->'active_session'
                )
            );
        END IF;

        -- Check if privilege_set_id exists
        IF NOT EXISTS (
            SELECT 1 FROM production.privilege_set_meta WHERE privilege_set_id = v_privilege_set_id
        ) THEN
            RETURN production.get_response_message(
                jsonb_build_object(
                    'data', jsonb_build_array(jsonb_build_object('error_code', '1005', 'message', 'Invalid privilege_set_id')),
                    'active_session', json_input->'active_session'
                )
            );
        END IF;

        -- Enforce either role or user (not both)
        IF (v_role_id IS NULL OR v_role_id = '') AND (v_user_id IS NULL OR v_user_id = '') THEN
            RETURN production.get_response_message(
                jsonb_build_object(
                    'data', jsonb_build_array(jsonb_build_object('error_code', '1006', 'message', 'Must provide either role_id or user_id')),
                    'active_session', json_input->'active_session'
                )
            );
        ELSIF (v_role_id IS NOT NULL AND v_role_id <> '') AND (v_user_id IS NOT NULL AND v_user_id <> '') THEN
            RETURN production.get_response_message(
                jsonb_build_object(
                    'data', jsonb_build_array(jsonb_build_object('error_code', '1007', 'message', 'Cannot assign to both role and user')),
                    'active_session', json_input->'active_session'
                )
            );
        END IF;

        -- Validate and map privileges
        IF NOT (item ? 'privilege_ids') OR jsonb_array_length(item->'privilege_ids') = 0 THEN
            RETURN production.get_response_message(
                jsonb_build_object(
                    'data', jsonb_build_array(jsonb_build_object('error_code', '1008', 'message', 'Missing or empty privilege_ids')),
                    'active_session', json_input->'active_session'
                )
            );
        END IF;

        FOR privilege_item IN SELECT * FROM jsonb_array_elements(item->'privilege_ids')
        LOOP
            INSERT INTO production.privilege_set_mapping (
                privilege_set_id, privilege_id, created_by
            )
            VALUES (
                v_privilege_set_id,
                trim(both '"' from privilege_item::text),
                current_user_id
            )
            ON CONFLICT DO NOTHING;
        END LOOP;

        -- Insert assignment
        IF v_role_id IS NOT NULL AND v_role_id <> '' THEN
            INSERT INTO production.privilege_set_assignment (
                privilege_set_id, role_id, assigned_by
            )
            VALUES (
                v_privilege_set_id, v_role_id, current_user_id
            )
            ON CONFLICT DO NOTHING;
        ELSE
            INSERT INTO production.privilege_set_assignment (
                privilege_set_id, user_id, assigned_by
            )
            VALUES (
                v_privilege_set_id, v_user_id, current_user_id
            )
            ON CONFLICT DO NOTHING;
        END IF;

        -- Add success entry
        response_array := response_array || jsonb_build_object(
            'privilege_set_id', v_privilege_set_id,
            'assigned_to', COALESCE(v_role_id, v_user_id),
            'status', 'assigned'
        );
    END LOOP;

    RETURN production.get_response_message(
        jsonb_build_object(
            'data', response_array,
            'active_session', json_input->'active_session'
        )
    );
END;
$function$
;
