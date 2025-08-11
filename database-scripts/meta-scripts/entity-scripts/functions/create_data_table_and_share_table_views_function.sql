-- DROP FUNCTION production.create_data_table_and_share_table_views_function(jsonb);

CREATE OR REPLACE FUNCTION production.create_data_table_and_share_table_views_function(item jsonb)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
DECLARE
    filter_clause text;
    inserted_entity_id varchar(22);
    filter jsonb;
    i integer;
    column_list text;
    current_data jsonb;
    view_name text;
    view_dev_name text;
    filter_by_owner text;
    existing_label text;
    current_user_id varchar(22);
    resolved_value text;
    is_standard boolean;
    dev varchar(255);
BEGIN
    -- Validate data structure
    IF item->'data' IS NULL OR jsonb_array_length(item->'data') = 0 THEN
        --RAISE EXCEPTION 'Invalid data structure: data array is missing or empty';
        RETURN  production.get_response_message(jsonb_build_object('data', jsonb_build_array(jsonb_build_object('error_code', '1002')), 'active_session', json_input->'active_session'));  -- The "data" field must be an array!
    END IF;

    -- assigning the standard value
    is_standard := (item->'standard')::boolean;
    -- Getting the user_id 
    SELECT user_id INTO current_user_id
    FROM production.login_session_meta
    WHERE session_token = item->'active_session'->>'session_token';

    IF current_user_id IS NULL THEN
        RETURN  production.get_response_message(jsonb_build_object('data', jsonb_build_array(jsonb_build_object('error_code', '1003')), 'active_session', json_input->'active_session')); -- Invalid session token
    END IF;
    
    -- Get entity_id from entity_meta table
    SELECT entity_id INTO inserted_entity_id 
    FROM production.entity_meta 
    WHERE developer_name = (production.remove_special_characters(item->>'entity'));

    -- Loop over each view entry in the 'data' array
    FOR i IN 0 .. jsonb_array_length(item->'data') - 1 LOOP
        current_data := item->'data'->i;

        -- Use default "name" column if not provided
        IF current_data->'columns' IS NULL OR jsonb_array_length(current_data->'columns') = 0 THEN
            current_data := jsonb_set(current_data, '{columns}', to_jsonb(ARRAY['name']));
        END IF;

        -- Extract column list: d.col1, d.col2, ...
        SELECT string_agg('d.' || quote_ident(col), ', ')
        INTO column_list
        FROM jsonb_array_elements_text(current_data->'columns') col;

        -- Reset filter clause
        filter_clause := '';

        -- Build filters
        IF current_data ? 'filters' THEN
            FOR filter IN (
                SELECT * FROM jsonb_array_elements(current_data->'filters') AS f(filter)
                WHERE (f.filter->>'operator') IS NOT NULL AND (f.filter->>'operator') <> ''
            )
            LOOP
                filter_clause := filter_clause || ' AND d.' || quote_ident(filter->>'column_developer_name');

                -- Resolve special values like 'today' to timestamp without time zone
                IF lower(filter->>'value') = 'today' THEN
                    resolved_value := to_char(current_date::timestamp, 'YYYY-MM-DD 00:00:00.000');
                ELSE
                    resolved_value := filter->>'value';
                END IF;

                CASE filter->>'operator'
                    WHEN 'equals' THEN filter_clause := filter_clause || ' = ' || quote_literal(resolved_value);
                    WHEN 'not equals' THEN filter_clause := filter_clause || ' != ' || quote_literal(resolved_value);
                    WHEN 'less than' THEN filter_clause := filter_clause || ' < ' || quote_literal(resolved_value);
                    WHEN 'greater than' THEN filter_clause := filter_clause || ' > ' || quote_literal(resolved_value);
                    WHEN 'less or equal' THEN filter_clause := filter_clause || ' <= ' || quote_literal(resolved_value);
                    WHEN 'greater or equal' THEN filter_clause := filter_clause || ' >= ' || quote_literal(resolved_value);
                    WHEN 'contains' THEN filter_clause := filter_clause || ' LIKE ' || quote_literal('%' || resolved_value || '%');
                    WHEN 'does not contain' THEN filter_clause := filter_clause || ' NOT LIKE ' || quote_literal('%' || resolved_value || '%');
                    WHEN 'starts with' THEN filter_clause := filter_clause || ' LIKE ' || quote_literal(resolved_value || '%');
                    ELSE
                        RAISE NOTICE 'Unsupported operator: % — skipping filter.', filter->>'operator';
                END CASE;
            END LOOP;
        END IF;

        -- Extract view metadata
        view_name := current_data->>'view_name';
        view_dev_name := production.remove_special_characters(current_data->>'view_developer_name');
        filter_by_owner := current_data->>'filter_by_owner';

        -- Create or Replace the view
        EXECUTE FORMAT(
            'CREATE OR REPLACE VIEW %I.%I AS 
            SELECT DISTINCT %s
            FROM %I.%I d
            INNER JOIN %I.%I s 
                ON (d.owner_id = s.user_id OR d.owner_id = s.group_id)
                AND d.%I = s.record_id
            %s %s;',
            item->>'data_space', view_dev_name,
            column_list,
            item->>'data_space', item->>'entity',
            item->>'data_space', item->>'entity' || '_share',
            item->>'entity' || '_id',  -- this creates `d.entityname_id = s.record_id`
            CASE 
                WHEN filter_by_owner = 'all' THEN ''
                WHEN filter_by_owner = 'my' THEN 'WHERE s.user_id = ' || quote_literal(current_user_id)
                ELSE ''
            END,
            filter_clause
        );


        RAISE NOTICE 'View % updated/created successfully.', view_dev_name;

        -- Check if view already exists and get its current label
        SELECT label INTO existing_label
        FROM production.view_meta
        WHERE developer_name = view_dev_name;

        -- Check if the view exists based on the developer name (assuming 'developer_name' is unique for each view)
        IF existing_label IS NOT NULL THEN
            -- If the view exists and the label has changed, update only the label
            IF existing_label <> view_name THEN
                UPDATE production.view_meta
                SET label = view_name,
                    last_modified_by = current_user_id, 
                    last_modified_date = CURRENT_TIMESTAMP
                WHERE developer_name = view_dev_name;

                RAISE NOTICE 'View metadata updated: Label changed to %.', view_name;
            ELSE
                RAISE NOTICE 'No changes required for view metadata.';
            END IF;
        ELSE
            -- If the view does not exist, insert it
            INSERT INTO production.view_meta (label, developer_name, entity_id, is_default_view, last_modified_by, created_by, standard)
            VALUES (
                view_name, 
                view_dev_name, 
                inserted_entity_id, 
                false,  -- Assuming 'false' for is_default_view; change as needed
                current_user_id, 
                current_user_id,
                CASE WHEN is_standard THEN true ELSE false END
            );

            RAISE NOTICE 'New view created: % with developer name %.', view_name, view_dev_name;
        END IF;

    END LOOP;

    RETURN TRUE;
END;
$function$
;
