CREATE OR REPLACE FUNCTION production.delete_from_ddl_function(json_input jsonb)
RETURNS jsonb
LANGUAGE plpgsql
AS $function$
DECLARE
    current_user_id text;
    current_user_permissions jsonb;
    entity_id_col text;
    delete_sql text;
    where_clause text;
    row jsonb;
    has_delete_permission boolean := false;
BEGIN
    -- Step 1: Basic input validation
    IF NOT (json_input ? 'data_space' AND json_input ? 'entity' AND json_input ? 'active_session' AND json_input ? 'data') THEN
        RETURN jsonb_build_object('error_code', '1001');  -- Missing required top-level keys
    END IF;

    entity_id_col := json_input->>'entity' || '_id';

    -- Step 2: Validate session and fetch user_id
    SELECT user_id INTO current_user_id
    FROM production.login_session_meta
    WHERE session_token = json_input->'active_session'->>'session_token';

    IF current_user_id IS NULL THEN
        RETURN jsonb_build_object('error_code', '1003');  -- Invalid session token
    END IF;

    -- Step 3: Fetch user access JSON
    SELECT user_permissions INTO current_user_permissions
    FROM production.user_access_json_view
    WHERE user_id = current_user_id;

    IF current_user_permissions IS NULL THEN
        RETURN jsonb_build_object('error_code', '1004');  -- User access not found
    END IF;

    -- Step 4: Check delete permission for the entity
    FOR row IN SELECT * FROM jsonb_array_elements(current_user_permissions->'entity_permissions') LOOP
        IF row->>'entity_developer_name' = json_input->>'entity'
           AND (row->>'access_level')::int & 2 = 2 THEN
            has_delete_permission := true;
            EXIT;
        END IF;
    END LOOP;

    IF NOT has_delete_permission THEN
        RETURN jsonb_build_object('error_code', '1204');  -- No delete permission for entity
    END IF;

    -- Step 5: Loop through records and delete
    FOR row IN SELECT * FROM jsonb_array_elements(json_input->'data') LOOP
        IF NOT row ? entity_id_col THEN
            RETURN jsonb_build_object('error_code', '1110');  -- Missing ID column in one of the records
        END IF;

        -- Delete from data table
        where_clause := format('%I = %L', entity_id_col, row->>entity_id_col);
        delete_sql := format('DELETE FROM %I.%I WHERE %s;', json_input->>'data_space', json_input->>'entity', where_clause);
        RAISE NOTICE 'Executing SQL: %', delete_sql;
        EXECUTE delete_sql;

        -- Delete from share table
        delete_sql := format(
            'DELETE FROM %I.%I_share WHERE record_id = %L AND user_id = %L;',
            json_input->>'data_space',
            json_input->>'entity',
            row->>entity_id_col,
            current_user_id
        );
        RAISE NOTICE 'Deleting from share table: %', delete_sql;
        EXECUTE delete_sql;
    END LOOP;

    RETURN jsonb_build_object('error_code', '0');  -- Success
END;
$function$;