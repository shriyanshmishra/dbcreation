CREATE OR REPLACE FUNCTION production.update_entity_data_table_and_share_table_views_function(target_entity_id TEXT, old_developer_name TEXT, old_label TEXT, new_developer_name TEXT, new_label TEXT)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    old_pk TEXT := old_developer_name || '_id';
    new_pk TEXT := new_developer_name || '_id';
    old_share TEXT := old_developer_name || '_share';
    new_share TEXT := new_developer_name || '_share';
    view_rec RECORD;
    updated_sql TEXT;
    standard_view_record RECORD;
    old_view_name TEXT;
    new_view_name TEXT;
BEGIN
    -- Loop through all views in the production schema that reference the old developer name
    FOR view_rec IN
        SELECT schemaname, viewname, definition
        FROM pg_views
        WHERE schemaname = 'production'
          AND definition ILIKE '%' || old_developer_name || '%'
    LOOP
        updated_sql := view_rec.definition;

        -- Replace table names and primary keys in the view definition
        updated_sql := REPLACE(updated_sql, 'production.' || old_share, 'production.' || new_share);
        updated_sql := REPLACE(updated_sql, 'production.' || old_developer_name, 'production.' || new_developer_name);
        updated_sql := REPLACE(updated_sql, 'd.' || old_pk, 'd.' || new_pk);

        -- Recreate the view with updated SQL
        EXECUTE format('CREATE OR REPLACE VIEW production.%I AS %s', view_rec.viewname, updated_sql);
    END LOOP;

    -- Loop through standard views and update view names in the view_meta table
    FOR standard_view_record IN 
        SELECT label, developer_name
        FROM production.view_meta
        WHERE entity_id = target_entity_id
          AND standard = true
    LOOP
        -- Generate the old and new view names
        old_view_name := standard_view_record.developer_name;
        new_view_name := 'all_' || new_developer_name || 's';
        
        -- Check if the new view name exists
        PERFORM 1
        FROM pg_views
        WHERE schemaname = 'production' AND viewname = new_view_name;

        -- If the new view does not exist, rename the old view
        IF NOT FOUND THEN
            -- Ensure that the old view exists before renaming
            PERFORM 1
            FROM pg_views
            WHERE schemaname = 'production' AND viewname = old_view_name;
            
            -- If the old view exists, rename it
            IF FOUND THEN
                EXECUTE format('ALTER VIEW production.%I RENAME TO %I', old_view_name, new_view_name);
            ELSE
                RAISE NOTICE 'View % does not exist, skipping rename', old_view_name;
            END IF;
        ELSE
            RAISE NOTICE 'View % already exists, skipping rename', new_view_name;
        END IF;

        -- Repeat for 'my_' and 'today_' views
        old_view_name := standard_view_record.developer_name;
        new_view_name := 'my_' || new_developer_name || 's';

        PERFORM 1
        FROM pg_views
        WHERE schemaname = 'production' AND viewname = new_view_name;

        IF NOT FOUND THEN
            PERFORM 1
            FROM pg_views
            WHERE schemaname = 'production' AND viewname = old_view_name;
            
            IF FOUND THEN
                EXECUTE format('ALTER VIEW production.%I RENAME TO %I', old_view_name, new_view_name);
            ELSE
                RAISE NOTICE 'View % does not exist, skipping rename', old_view_name;
            END IF;
        ELSE
            RAISE NOTICE 'View % already exists, skipping rename', new_view_name;
        END IF;

        old_view_name := standard_view_record.developer_name;
        new_view_name := 'today_' || new_developer_name || 's';

        PERFORM 1
        FROM pg_views
        WHERE schemaname = 'production' AND viewname = new_view_name;

        IF NOT FOUND THEN
            PERFORM 1
            FROM pg_views
            WHERE schemaname = 'production' AND viewname = old_view_name;
            
            IF FOUND THEN
                EXECUTE format('ALTER VIEW production.%I RENAME TO %I', old_view_name, new_view_name);
            ELSE
                RAISE NOTICE 'View % does not exist, skipping rename', old_view_name;
            END IF;
        ELSE
            RAISE NOTICE 'View % already exists, skipping rename', new_view_name;
        END IF;

        -- Now update the entries in the view_meta table with the new names
        UPDATE production.view_meta
        SET 
            label = CASE
                        WHEN label LIKE 'All %' THEN 'All ' || new_label || 's'
                        WHEN label LIKE 'My %' THEN 'My ' || new_label || 's'
                        WHEN label LIKE 'Today %' THEN 'Today ' || new_label || 's'
                    END,
            developer_name = CASE
                                WHEN developer_name LIKE 'all_%' THEN 'all_' || new_developer_name || 's'
                                WHEN developer_name LIKE 'my_%' THEN 'my_' || new_developer_name || 's'
                                WHEN developer_name LIKE 'today_%' THEN 'today_' || new_developer_name || 's'
                            END
        WHERE entity_id = target_entity_id
        AND developer_name = standard_view_record.developer_name
        AND standard = true;

    END LOOP;
END;
$$; 
