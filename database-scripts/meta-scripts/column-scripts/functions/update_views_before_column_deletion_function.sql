CREATE OR REPLACE FUNCTION production.update_views_before_column_deletion_function(json_input jsonb)
RETURNS jsonb
LANGUAGE plpgsql
AS $function$
DECLARE
    target_entity_id TEXT;
    data_space TEXT;
    deleted_column_names TEXT[] := ARRAY[]::TEXT[];
    view_dev_name TEXT;
    full_view_name TEXT;
    original_view_sql TEXT;
    updated_view_sql TEXT;
    column_record JSONB;
    current_column TEXT;
    select_clause TEXT;
    from_clause TEXT;
    column_used BOOLEAN;
BEGIN
    -- Extract entity_id and data_space
    target_entity_id := json_input->>'entity_id';
    data_space := json_input->>'data_space';

    -- Collect all developer_names of deleted columns into array
    FOR column_record IN SELECT * FROM jsonb_array_elements(json_input->'data')
    LOOP
        deleted_column_names := array_append(deleted_column_names, column_record->>'developer_name');
    END LOOP;

    -- Loop through all views for this entity
    FOR view_dev_name IN
        SELECT developer_name
        FROM production.view_meta
        WHERE entity_id = target_entity_id
    LOOP
        full_view_name := format('%I.%I', data_space, view_dev_name);
        RAISE NOTICE 'Processing view: %', full_view_name;

        -- Get the current definition of the view
        EXECUTE format('SELECT definition FROM pg_views WHERE schemaname = %L AND viewname = %L;', data_space, view_dev_name)
        INTO original_view_sql;

        IF original_view_sql IS NULL THEN
            RAISE NOTICE 'No view found with schema % and name %', data_space, view_dev_name;
            CONTINUE;
        END IF;

        -- Check if any deleted column is used in the view
        column_used := FALSE;
        FOREACH current_column IN ARRAY deleted_column_names LOOP
            IF position('d.' || quote_ident(current_column) IN original_view_sql) > 0 THEN
                column_used := TRUE;
                EXIT; -- One match is enough to proceed
            END IF;
        END LOOP;

        -- Skip view if no deleted column is found
        IF NOT column_used THEN
            RAISE NOTICE 'No deleted columns found in view %, skipping update.', full_view_name;
            CONTINUE;
        END IF;

        -- Extract SELECT and FROM clauses
        select_clause := substring(original_view_sql FROM 'SELECT.*?FROM');
        from_clause := substring(original_view_sql FROM 'FROM.*');

        -- Remove the deleted columns from the SELECT clause
        FOREACH current_column IN ARRAY deleted_column_names LOOP
            select_clause := regexp_replace(select_clause,
                ',\s*d\.' || quote_ident(current_column) || '(\s*,|\s+FROM)',
                '\1', 'gi');

            select_clause := regexp_replace(select_clause,
                'SELECT\s+DISTINCT\s+d\.' || quote_ident(current_column) || '(\s*,|\s+FROM)',
                'SELECT DISTINCT', 'gi');
        END LOOP;

        -- Clean up select_clause
        select_clause := regexp_replace(select_clause, ',\s+FROM', ' FROM', 'gi');
        select_clause := regexp_replace(select_clause, 'SELECT\s+DISTINCT\s+,', 'SELECT DISTINCT ', 'gi');
        select_clause := regexp_replace(select_clause, ',\s*,', ',', 'gi');
        select_clause := regexp_replace(select_clause, '\s+FROM\s*$', '', 'gi');
        select_clause := regexp_replace(select_clause, ',\s*$', '', 'gi');

        -- Rebuild SQL
        updated_view_sql := 'CREATE OR REPLACE VIEW ' || full_view_name || ' AS ' || select_clause || ' ' || from_clause;

        RAISE NOTICE 'Updated SQL --> %', updated_view_sql;

        -- Drop and recreate the view
        EXECUTE format('DROP VIEW IF EXISTS %I.%I CASCADE', data_space, view_dev_name);
        EXECUTE updated_view_sql;
    END LOOP;
	RAISE NOTICE 'Json Input: %',json_input;
	
	--Calling production.delete_entity_data_table_column_function
	PERFORM production.delete_entity_data_table_column_function(json_input);
	RETURN json_input;
END;
$function$
;