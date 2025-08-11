CREATE OR REPLACE FUNCTION production.insert_into_ddl_function(json_input jsonb)
RETURNS jsonb
LANGUAGE plpgsql
AS $function$
DECLARE
    schema_name text := json_input->>'data_space';
    entity_name text := json_input->>'entity';
    current_session_token text := json_input->'active_session'->>'session_token';
    current_user_id text;
    current_user_permissions jsonb;
    allowed_columns text[] := '{}';
    json_keys text[];
    insert_cols text := '';
    col_defs text := '';
    insert_sql text;
    id_col text;
    share_table text := format('%I.%I_share', schema_name, entity_name);
    col text;
    col_record record;
    permission jsonb;
    row jsonb;
    new_data jsonb := '[]'::jsonb;
    current_entity_id text;
    current_column_id text;
BEGIN
    -- Step 1: Validate input structure
    IF NOT (json_input ? 'data_space' AND json_input ? 'entity' AND json_input ? 'active_session' AND json_input ? 'data') THEN
        RETURN jsonb_build_object('error_code', '1001');  -- Missing required top-level keys
    END IF;

    -- Step 2: Resolve user ID from session token
    SELECT user_id INTO current_user_id
    FROM production.login_session_meta
    WHERE session_token = current_session_token;

    IF current_user_id IS NULL THEN
        RETURN jsonb_build_object('error_code', '1003');  -- Invalid session token
    END IF;

    -- Step 3: Load permissions
    SELECT user_permissions INTO current_user_permissions
    FROM production.user_access_json_view
    WHERE user_id = current_user_id;

    IF current_user_permissions IS NULL THEN
        RETURN jsonb_build_object('error_code', '1004');  -- User access JSON not found
    END IF;

    -- Step 4: Check if table exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = schema_name AND table_name = entity_name
    ) THEN
        RETURN jsonb_build_object('error_code', '1005');  -- Entity not found
    END IF;

    -- Step 5: Restructure each data object to include standard columns
    FOR row IN SELECT * FROM jsonb_array_elements(json_input->'data') LOOP
        row := row || jsonb_build_object(
            'created_by', current_user_id,
            'last_modified_by', current_user_id,
            'owner_id', current_user_id
        );
        new_data := new_data || jsonb_build_array(row);
    END LOOP;

    -- Step 6: Get all keys from the first data object
    SELECT array_agg(key) INTO json_keys
    FROM jsonb_object_keys(new_data->0) AS key;

    -- Getting the entity_id
    SELECT entity_id INTO current_entity_id
    FROM production.entity_meta
    WHERE developer_name = entity_name;

    FOREACH col IN ARRAY json_keys LOOP
        SELECT column_id, entity_id INTO current_column_id, current_entity_id
        FROM production.column_meta
        WHERE developer_name = col
            AND entity_id = current_entity_id;

        -- Check permission using your function
        IF production.check_permission(current_user_id, current_entity_id, current_column_id) THEN
            allowed_columns := array_append(allowed_columns, col);
        ELSE
            RETURN jsonb_build_object(
                'error_code', '1200',
                'message', format('User does not have permission to insert in column: %s', col)
            );
        -- No permission for column
        END IF;
    END LOOP;
    -- Step 8: Build ordered column names and types
    DECLARE
        ordered_cols RECORD;
        insert_col_list text := '';
        col_def_list text := '';
    BEGIN
        FOR ordered_cols IN
            SELECT column_name, udt_name
            FROM information_schema.columns
            WHERE table_schema = schema_name
              AND table_name = entity_name
              AND column_name = ANY (allowed_columns)
              AND is_generated = 'NEVER'
              AND identity_generation IS NULL
            ORDER BY ordinal_position
        LOOP
            insert_col_list := insert_col_list || format('%I, ', ordered_cols.column_name);
            col_def_list := col_def_list || format('%I %s, ', ordered_cols.column_name, ordered_cols.udt_name);
        END LOOP;

        insert_cols := left(insert_col_list, length(insert_col_list) - 2);
        col_defs := left(col_def_list, length(col_def_list) - 2);
    END;

    -- Step 9: Identify ID column (varchar(22) and ends with _id)
    SELECT column_name INTO id_col
    FROM information_schema.columns
    WHERE table_schema = schema_name
      AND table_name = entity_name
      AND udt_name = 'varchar'
      AND character_maximum_length = 22
      AND column_name LIKE '%\_id' ESCAPE '\'
    ORDER BY ordinal_position
    LIMIT 1;

    IF id_col IS NULL THEN
        RETURN jsonb_build_object('error_code', '1110');  -- No varchar(22) ID column found
    END IF;

    -- Step 10: Construct and run dynamic insert statement
    insert_sql := format(
        'INSERT INTO %I.%I (%s)
         SELECT * FROM jsonb_to_recordset($1) AS t(%s)
         RETURNING %I',
        schema_name, entity_name, insert_cols, col_defs, id_col
    );

    -- Step 11: Inserting entries of each record into the share table 
    FOR col IN EXECUTE insert_sql USING new_data LOOP
        EXECUTE format(
            'INSERT INTO %s (user_id, record_id, created_by, last_modified_by)
             VALUES ($1, $2, $3, $3)',
            share_table
        ) USING current_user_id, col, current_user_id;
    END LOOP;

    RETURN jsonb_build_object('error_code', '0');  -- Success
END;
$function$;