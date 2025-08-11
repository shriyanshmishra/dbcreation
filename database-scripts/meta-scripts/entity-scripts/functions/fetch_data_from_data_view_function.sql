CREATE OR REPLACE FUNCTION production.fetch_data_from_data_view_function(data_view_json jsonb)
RETURNS SETOF JSONB
LANGUAGE plpgsql
AS $function$
DECLARE
    current_user_id TEXT;
    current_user_permissions JSONB;
    column_list TEXT := '';
    col_name TEXT;
    col JSONB;
    sql_query TEXT;
    view_columns TEXT[];
BEGIN
    -- Step 1: Get user_id from session
    SELECT user_id INTO current_user_id
    FROM production.login_session_meta
    WHERE session_token = data_view_json->'active_session'->>'session_token';

    IF current_user_id IS NULL THEN
        --RAISE EXCEPTION 'Invalid session token';
        RETURN NEXT jsonb_build_object('error_code', '1003');  -- Invalid session token
    END IF;

    -- Step 2: Get user's permission JSON
    SELECT user_permissions INTO current_user_permissions
    FROM production.user_access_json_view
    WHERE user_id = current_user_id;

    IF current_user_permissions IS NULL THEN
        --RAISE EXCEPTION 'No permissions found for user %', current_user_id;
        RETURN NEXT jsonb_build_object('error_code', '1004');  -- User access JSON not found
    END IF;

    -- Step 3: Get actual column names from the target view
    SELECT array_agg(column_name)
    INTO view_columns
    FROM information_schema.columns
    WHERE table_schema = 'production'
      AND table_name = data_view_json->>'view_developer_name';

    -- Step 4: Build list of valid and accessible columns
    FOR col IN SELECT * FROM jsonb_array_elements(current_user_permissions->'column_permissions')
    LOOP
        IF (col->>'entity_developer_name') = data_view_json->>'entity_developer_name'
           AND ((col->>'access_level')::int & 2) = 2 THEN
            col_name := col->>'column_developer_name';

            -- Only include the column if it exists in the view
            IF col_name = ANY(view_columns) THEN
                column_list := column_list || quote_ident(col_name) || ', ';
            END IF;
        END IF;
    END LOOP;

    column_list := rtrim(column_list, ', ');

    IF column_list = '' THEN
        --RAISE EXCEPTION 'No valid readable columns for this user on entity/view %', data_view_json->>'entity_developer_name';
        RETURN NEXT jsonb_build_object('error_code', '1201');  -- User has no access to view this data
    END IF;

    -- Step 5: Build and execute dynamic SQL to return rows as JSONB
    sql_query := FORMAT(
        'SELECT to_jsonb(subq) FROM (SELECT %s FROM %I.%I) AS subq',
        column_list,
        'production',
        data_view_json->>'view_developer_name'
    );

    -- Optional: debug output
    RAISE NOTICE 'Running SQL: %', sql_query;

    RETURN QUERY EXECUTE sql_query;

END;
$function$;