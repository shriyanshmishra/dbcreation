CREATE OR REPLACE FUNCTION production.update_into_ddl_function(json_input jsonb)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
    current_user_id text;
    current_user_permissions jsonb;
    allowed_columns text[] := '{}';
    json_keys text[];
    row jsonb;
    set_clause text := '';
    update_sql text;
    col_record jsonb;
    col text;
    where_clause text := '';
    unauthorized_columns text[] := '{}';
    has_permission boolean;
	entity_id_col text;
    entity_key_col text;
BEGIN
    -- Step 1: Basic input validation
    IF NOT (json_input ? 'data_space' AND json_input ? 'entity' AND json_input ? 'active_session' AND json_input ? 'data') THEN
        RETURN jsonb_build_object('error_code', '1001');  -- Missing required top-level keys
    END IF;

    -- Step 2: Validate session
    SELECT user_id INTO current_user_id
    FROM production.login_session_meta
    WHERE session_token = json_input->'active_session'->>'session_token';

    IF current_user_id IS NULL THEN
        RETURN jsonb_build_object('error_code', '1002');  -- Invalid session token
    END IF;

    -- Step 3: Fetch user access JSON
    SELECT user_permissions INTO current_user_permissions
    FROM production.user_access_json_view
    WHERE user_id = current_user_id;

    IF current_user_permissions IS NULL THEN
        RETURN jsonb_build_object('error_code', '1003');  -- User access JSON not found
    END IF;

    -- Step 4: Validate entity exists
    PERFORM 1 FROM production.entity_meta
    WHERE developer_name = json_input->>'entity';

    IF NOT FOUND THEN
        RETURN jsonb_build_object('error_code', '1004');  -- Entity not found
    END IF;

	entity_id_col := json_input->>'entity' || '_id';
	entity_key_col := json_input->>'entity' || '_key';

    -- Step 5: Fetch columns of the entity data table, excluding standard columns
    SELECT array_agg(column_name)
    INTO allowed_columns
    FROM information_schema.columns
    WHERE table_schema = json_input->>'data_space'
      AND table_name = json_input->>'entity'
      AND column_name NOT IN (
          entity_id_col,
          entity_key_col,
          'created_date',
          'last_modified_date'
      );

    -- Step 6: Iterate through each data object in the array
    FOR row IN SELECT * FROM jsonb_array_elements(json_input->'data') LOOP
        -- Add system fields
        row := row || jsonb_build_object('last_modified_by', current_user_id);
        row := row || jsonb_build_object('created_by', current_user_id);
        row := row || jsonb_build_object('owner_id', current_user_id);

        -- Collect all keys (columns)
        SELECT array_agg(key) INTO json_keys
        FROM jsonb_object_keys(row) AS key;

        -- Step 7: Validate each column
        unauthorized_columns := '{}'; -- reset
        FOREACH col IN ARRAY json_keys LOOP
            IF col = entity_id_col OR col = entity_key_col OR col = 'created_date' OR col = 'last_modified_date' THEN
			    CONTINUE;
			END IF;

            -- First check if it's in allowed columns
            IF NOT col = ANY(allowed_columns) THEN
                unauthorized_columns := array_append(unauthorized_columns, col);
                CONTINUE;
            END IF;

            -- Then check if user has update permission
            has_permission := false;
            FOR col_record IN SELECT * FROM jsonb_array_elements(current_user_permissions->'column_permissions') LOOP
                IF col_record->>'entity_developer_name' = json_input->>'entity'
                   AND col_record->>'column_developer_name' = col
                   AND (col_record->>'access_level')::int & 2 = 2 THEN
                    has_permission := true;
                    EXIT;
                END IF;
            END LOOP;

            IF NOT has_permission THEN
                unauthorized_columns := array_append(unauthorized_columns, col);
				RAISE NOTICE 'un_column--------:-> %',unauthorized_columns;
            END IF;
        END LOOP;

        IF array_length(unauthorized_columns, 1) > 0 THEN
--			RAISE EXCEPTION 'You don''t have permission to update the following column(s): %',
--                array_to_string(unauthorized_columns, ', ');
            RETURN jsonb_build_object('error_code', '1006');  -- Unauthorized column update attempt
        END IF;

        -- Step 8: Build SET clause
        set_clause := '';
        FOREACH col IN ARRAY allowed_columns LOOP
            IF row ? col THEN
                set_clause := set_clause || format('%I = %L, ', col, row->>col);
            END IF;
        END LOOP;

        -- Remove the last comma and space
        IF set_clause <> '' THEN
            set_clause := left(set_clause, length(set_clause) - 2);
        END IF;

        -- Step 9: WHERE clause using ID
        IF row ? (json_input->>'entity' || '_id') THEN
            where_clause := format('%I = %L', json_input->>'entity' || '_id', row->>(json_input->>'entity' || '_id'));
        ELSE
            RETURN jsonb_build_object('error_code', '1005');  -- Missing ID column for update
        END IF;

        -- Step 10: Execute dynamic update SQL
        update_sql := format(
            'UPDATE %I.%I SET %s WHERE %s;',
            json_input->>'data_space', json_input->>'entity', set_clause, where_clause
        );

        RAISE NOTICE 'Executing SQL: %', update_sql;
        EXECUTE update_sql;
    END LOOP;

    RETURN jsonb_build_object('error_code', '0');  -- Success
END;
$$;