CREATE OR REPLACE FUNCTION production.fetch_data_from_meta_view_function(meta_view_json jsonb)
RETURNS jsonb
LANGUAGE plpgsql
AS $function$
DECLARE
    current_user_id varchar(22);
    current_user_permissions JSONB;
    has_access BOOLEAN := FALSE;
    result_array JSONB := '[]';
BEGIN
    -- Step 1: Get user_id from session
    SELECT user_id INTO current_user_id
    FROM production.login_session_meta
    WHERE session_token = meta_view_json->'active_session'->>'session_token';

    IF current_user_id IS NULL THEN
        --RAISE EXCEPTION 'Invalid session token';
        RETURN jsonb_build_object('error_code', '1003');  -- Invalid session token
    END IF;

    -- Step 2: Fetch user permission JSON
    SELECT user_permissions INTO current_user_permissions
    FROM production.user_access_json_view
    WHERE user_id = current_user_id;

    If current_user_permissions IS NULL THEN
        --RAISE EXCEPTION 'No permissions found for user %', current_user_id;
        RETURN jsonb_build_object('error_code', '1004');  -- User access JSON not found
    END IF;

    -- Step 3: Check if user has 'access_setup' system privilege
    IF current_user_permissions IS NOT NULL THEN
        SELECT EXISTS (
            SELECT 1
            FROM jsonb_array_elements(current_user_permissions->'system_permissions') AS sp
            JOIN production.system_privilege_meta spm 
              ON spm.system_privilege_id = (sp->>'system_privilege_id')::VARCHAR
            JOIN production.system_privilege_master_meta spmm
              ON spmm.system_privilege_master_id = spm.system_privilege_master_id
            WHERE spmm.permission_name = 'access_setup'
              AND (sp->>'type') = 'true'
        ) INTO has_access;
    END IF;

    -- Step 4: Return array of JSONB rows if access granted
    IF has_access THEN
        SELECT jsonb_agg(to_jsonb(t)) INTO result_array
        FROM production.entity_meta_view t;

        RETURN result_array;
    ELSE
        --RAISE EXCEPTION 'User does not have access privilege';
        RETURN jsonb_build_object('error_code', '1201');  -- User does not have access privilege
    END IF;
END;
$function$;