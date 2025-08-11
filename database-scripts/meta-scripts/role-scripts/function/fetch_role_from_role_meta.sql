-- DROP FUNCTION production.fetch_all_roles_function(jsonb);

CREATE OR REPLACE FUNCTION production.fetch_role_from_role_meta(input_json jsonb)
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
    WHERE session_token = input_json->'active_session'->>'session_token';

    IF current_user_id IS NULL THEN
        RETURN jsonb_build_object('error_code', '1003'); -- Invalid session token
    END IF;

    -- Step 2: Fetch user permissions
    SELECT user_permissions INTO current_user_permissions
    FROM production.user_access_json_view
    WHERE user_id = current_user_id;

    IF current_user_permissions IS NULL THEN
        RETURN jsonb_build_object('error_code', '1004'); -- No permissions found
    END IF;

    -- Step 3: Check for 'access_setup' permission
    SELECT EXISTS (
        SELECT 1
        FROM jsonb_array_elements(current_user_permissions->'system_permissions') AS sp
        JOIN production.system_privilege_meta spm 
            ON spm.system_privilege_id = (sp->>'system_privilege_id')::varchar
        JOIN production.system_privilege_master_meta spmm 
            ON spmm.system_privilege_master_id = spm.system_privilege_master_id
        WHERE spmm.permission_name = 'access_setup'
        AND (sp->>'type') = 'true'
    ) INTO has_access;

    -- Step 4: Return role data if access granted
    IF has_access THEN
        SELECT jsonb_agg(jsonb_build_object('Role', developer_name))
        INTO result_array
        FROM production.role_meta
        ORDER BY created_date;

        RETURN jsonb_build_object(
            'data', result_array,
            'active_session', input_json->'active_session'
        );
    END IF;

    -- No access
    RETURN jsonb_build_object('error_code', '1201'); -- No access permission
END;
$function$
;
