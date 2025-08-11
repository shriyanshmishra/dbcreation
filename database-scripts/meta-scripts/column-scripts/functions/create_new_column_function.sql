-- DROP FUNCTION production.create_new_column_function(jsonb);

CREATE OR REPLACE FUNCTION production.create_new_column_function(column_json jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    item jsonb;
    picklist_entry jsonb;
    entity_developer_name text;
    entity_table_name text;
    entity_prefix bpchar(3);
    on_delete_action TEXT;
    fk_constraint_name TEXT;
    is_not_null BOOLEAN;
    parent_entity_developer_name TEXT;
    inserted_column_id varchar(22);
    pg_data_type TEXT;
    insterting_privilege_id varchar(22);
    is_accessible BOOLEAN;
    current_user_id varchar(22);
    current_access_level integer;
inserting_privilege_id varchar(22); 
    dev_name varchar(255);
    v_picklist_id      VARCHAR(22);
 has_permission jsonb;
BEGIN
    -- Step 1 : Validate JSON structure
    IF NOT (column_json ? 'data_space' AND column_json ? 'meta_table' AND column_json ? 'active_session' AND column_json ? 'data') THEN
       RETURN production.get_response_message(
  jsonb_build_object(
    'data', jsonb_build_array(jsonb_build_object('error_code', '1001'))
  )
);
-- Missing required top-level keys!
    END IF;
    RAISE NOTICE 'Top-level keys validated';

    -- Step 2 : Ensure `data` is an array
    IF jsonb_typeof(column_json->'data') <> 'array' THEN
        RETURN production.get_response_message(
  jsonb_build_object(
    'data', jsonb_build_array(jsonb_build_object('error_code', '1002'))
  )
);
  -- "data" field must be an array!
    END IF;
    RAISE NOTICE 'Data field is an array';

    RAISE NOTICE 'COLUMN DATA : % ',column_json->'data';



SELECT production.check_user_has_privilege(jsonb_build_object(
    'data_space', column_json->>'data_space',
    'active_session', column_json->'active_session',
    'privilege_name', 'Manage Fields'
)) INTO has_permission;

IF NOT (has_permission->>'has_privilege')::boolean THEN
    RETURN production.get_response_message(jsonb_build_object(
        'data', jsonb_build_array(jsonb_build_object('error_code', '1905')),
        'active_session', column_json->'active_session'
    ));
END IF;

    -- Step 3 : Getting user_id From session_token
    SELECT user_id INTO current_user_id
    FROM production.login_session_meta
    WHERE session_token = column_json->'active_session'->>'session_token';

    IF current_user_id IS NULL THEN
        RETURN production.get_response_message(
  jsonb_build_object(
    'data', jsonb_build_array(jsonb_build_object('error_code', '1003'))
  )
);-- Invalid session token
    END IF;

    -- Step 4: Check if the table schema exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.schemata
        WHERE schema_name = column_json->>'data_space'
    ) THEN
        RETURN production.get_response_message(
  jsonb_build_object(
    'data', jsonb_build_array(jsonb_build_object('error_code', '1005'))
  )
);
   -- Schema does not exist
    END IF;
    RAISE NOTICE 'Schema exists';

    -- Step 5 : Check if the meta table exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = column_json->>'data_space'
        AND table_name = column_json->>'meta_table'
    ) THEN
        RETURN production.get_response_message(
  jsonb_build_object(
    'data', jsonb_build_array(jsonb_build_object('error_code', '1006'))
  )
);
 -- Meta table does not exist
    END IF;
    RAISE NOTICE 'Meta table exists';

    -- Loop through each item in the "data" array to check for data tables
    FOR item IN SELECT * FROM jsonb_array_elements(column_json->'data') LOOP
        -- **ADD THIS VALIDATION HERE**
        IF item->>'developer_name' IS NULL OR item->>'developer_name' = '' THEN
            RETURN production.get_response_message(
  jsonb_build_object(
    'data', jsonb_build_array(jsonb_build_object('error_code', '1107'))
  )
);

        END IF;

        dev_name := production.remove_special_characters( item->>'developer_name');
        RAISE NOTICE 'entity lable % ',dev_name;

        --Checking entity existence
        IF NOT EXISTS (
            SELECT 1 FROM production.entity_meta WHERE entity_id = item->>'entity_id'
        ) THEN
            RETURN  production.get_response_message(
  jsonb_build_object(
    'data', jsonb_build_array(jsonb_build_object('error_code', '1006'))
  )
);
   -- (This error code seems reused, consider a new one for entity not found)
        END IF;

        --Extracting developer_name from the entity_meta table
        SELECT developer_name, prefix INTO entity_developer_name, entity_prefix
        FROM production.entity_meta
        WHERE entity_id = item->>'entity_id'; -- Here entity_id is used to find the developer_name

        RAISE NOTICE 'Data table for entity_id "%" & "%" & "%" exists', item->>'entity_id', entity_developer_name, entity_prefix;

        -- Define table name dynamically
        -- entity_table_name := format('%I.%I', column_json->>'data_space', entity_developer_name); -- This is now redundant

        -- Check if column exists in the actual table
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = column_json->>'data_space'
            AND table_name = entity_developer_name -- Here entity_developer_name (the actual table name) is used
            AND column_name = dev_name -- Here dev_name (the actual column name) is used
        ) THEN
            RAISE NOTICE 'Entered in the if else part';
            RAISE NOTICE 'label : % ',item->>'label';
            -- Handle different data types
            IF item->>'data_type' = 'key' THEN
                EXECUTE format(
                    'ALTER TABLE %I.%I ADD COLUMN %I smallserial;',
                    column_json->>'data_space',
                    entity_developer_name, -- entity_developer_name is the actual table name
                    format('%s_key', entity_developer_name) -- Dynamically created column name
                );
            ELSEIF item->>'data_type' = 'id' THEN
                -- Ensuring accessible is set to false
                is_accessible := true;
                EXECUTE format(
                    'ALTER TABLE %I.%I ADD COLUMN IF NOT EXISTS %I varchar(22)
                     GENERATED ALWAYS AS (%L || lpad(%I::text, 19, ''0'')) STORED NOT NULL;',
                    column_json->>'data_space',
                    entity_developer_name, -- entity_developer_name is the actual table name
                    format('%s_id', entity_developer_name), -- Dynamically created column name
                    entity_prefix,
                    format('%s_key', entity_developer_name) -- Reference to the key column
                );

                --Ensure the ID column is set as the PRIMARY KEY
                EXECUTE format(
                    'ALTER TABLE %I.%I ADD CONSTRAINT %I PRIMARY KEY (%I);',
                    column_json->>'data_space',
                    entity_developer_name, -- entity_developer_name is the actual table name
                    format('pk_%s', entity_developer_name), -- Dynamically created constraint name
                    format('%s_id', entity_developer_name) -- Reference to the ID column
                );

                --Ensure index exists for entity_id column
                EXECUTE format(
                    'CREATE INDEX IF NOT EXISTS %I ON %I.%I (%I);',
                    format('idx_%s_id', entity_developer_name), -- Dynamically created index name
                    column_json->>'data_space',
                    entity_developer_name, -- entity_developer_name is the actual table name
                    format('%s_id', entity_developer_name) -- Reference to the ID column
                );
                -- Insert column metadata into column_meta table
                INSERT INTO production.column_meta (
                    label, entity_id, developer_name, data_type,pg_data_type, is_deletable, created_by, last_modified_by
                ) VALUES (
                    item->>'label',
                    item->>'entity_id', -- Here, entity_id is used for metadata
                    dev_name, -- dev_name (the developer name for the column) is stored
                    item->>'data_type',
                    item->>'pg_data_type',
                    false,
                    current_user_id,
                    current_user_id

                )
                RETURNING column_id INTO inserted_column_id; -- column_id is retrieved for metadata

ELSEIF item->>'data_type' = 'formula' THEN
    -- Add a column to hold the formula result (text, numeric, boolean, etc.)
    EXECUTE format(
        'ALTER TABLE %I.%I ADD COLUMN IF NOT EXISTS %I %s;',
        column_json->>'data_space',
        entity_developer_name,
        dev_name,             -- column name from developer_name
        item->>'pg_data_type' -- underlying PostgreSQL data type
    );

    -- Insert metadata including formula expression (if provided)
    INSERT INTO production.column_meta (
        label, entity_id, developer_name, data_type, pg_data_type, formula_expression, is_deletable, created_by, last_modified_by
    ) VALUES (
        item->>'label',
        item->>'entity_id',
        dev_name,
        item->>'data_type',
        item->>'pg_data_type',
        item->>'formula_expression', -- formula expression string from JSON input
        false,
        current_user_id,
        current_user_id
    )
    RETURNING column_id INTO inserted_column_id;

            ELSIF item->>'data_type' = 'lookup' THEN
                -- Ensuring accessible is set to true
                is_accessible := true;

                -- Ensure parent_entity_id is provided for relationships
                IF NOT item ? 'parent_entity_id' THEN
               RETURN production.get_response_message(
  jsonb_build_object(
    'data', jsonb_build_array(jsonb_build_object('error_code', '1103'))
  )
);
   -- parent_entity_id is required for lookup fields!
                END IF;
                RAISE NOTICE 'parent id %',item->>'parent_entity_id';
                -- Now checking for developer_name
                CASE
                    WHEN  dev_name IN ('created_by', 'last_modified_by', 'owner_id') THEN
                        RAISE NOTICE 'Enter in 1 part: % ', dev_name;
                        -- Define foreign key constraint name
                        fk_constraint_name := format('fk_%I_%I', entity_developer_name,  dev_name);

                        -- Add foreign key column
                        EXECUTE format(
                            'ALTER TABLE %I.%I ADD COLUMN %I varchar(22);',
                            column_json->>'data_space',
                            entity_developer_name, -- Actual table name
                            dev_name -- Actual column name
                        );

                        -- Add foreign key constraint
                        EXECUTE format(
                            'ALTER TABLE %I.%I ADD CONSTRAINT %I FOREIGN KEY (%I) REFERENCES production."user"(user_id) ON DELETE SET NULL;',
                            column_json->>'data_space',
                            entity_developer_name, -- Actual table name
                            fk_constraint_name,
                            dev_name -- Actual column name
                        );

                        -- Create index for performance
                        EXECUTE format(
                            'CREATE INDEX %I ON %I.%I(%I);',
                            format('idx_%I_%I', entity_developer_name, dev_name), -- Dynamically created index name
                            column_json->>'data_space',
                            entity_developer_name, -- Actual table name
                            dev_name -- Actual column name
                        );

                    ELSE
                        -- Fetch parent entity developer name
                        SELECT developer_name INTO parent_entity_developer_name
                        FROM production.entity_meta
                        WHERE entity_id = item->>'parent_entity_id';

                        -- Define foreign key constraint name
                        fk_constraint_name := format('fk_%I_%I', entity_developer_name,  dev_name);

                        -- Define on delete action
                        IF item->>'do_not_allow_deletion' = 'true' THEN
                            on_delete_action := 'ON DELETE RESTRICT';
                        ELSIF item->>'if_delete_clean_values' = 'true' THEN
                            on_delete_action := 'ON DELETE SET NULL';
                        ELSE
                            on_delete_action := ''; -- Default to no specific action if neither is true
                        END IF;

                        -- Mark column as NOT NULL if 'required' is true
                        IF item ? 'required' AND item->>'required' = 'true' THEN
                            is_not_null := true;
                        ELSE
                            is_not_null := false;
                        END IF;

                        -- Creating the actual column
                        IF is_not_null IS TRUE THEN
                            -- Adding Column with NOT NULL
                            EXECUTE format(
                                'ALTER TABLE %I.%I ADD COLUMN %I varchar(22) NOT NULL;',
                                column_json->>'data_space',
                                entity_developer_name, -- Actual table name
                                dev_name -- Actual column name
                            );
                        ELSE
                            -- Adding Column without NOT NULL
                            EXECUTE format(
                                'ALTER TABLE %I.%I ADD COLUMN %I varchar(22);',
                                column_json->>'data_space',
                                entity_developer_name, -- Actual table name
                                dev_name -- Actual column name
                            );
                        END IF;

                        -- Adding Foreign key and Constraints
                        EXECUTE format(
                            'ALTER TABLE %I.%I ADD CONSTRAINT %I FOREIGN KEY (%I) REFERENCES %I.%I(%I_id) %s;',
                            column_json->>'data_space',
                            entity_developer_name, -- Actual table name
                            fk_constraint_name,
                            dev_name, -- Actual column name
                            column_json->>'data_space',
                            parent_entity_developer_name, -- Actual parent table name
                            parent_entity_developer_name, -- Used for parent_table_name_id
                            on_delete_action
                        );

                        -- Create index for performance
                        EXECUTE format(
                            'CREATE INDEX %I ON %I.%I(%I);',
                            format('idx_%I_%I', entity_developer_name, dev_name), -- Dynamically created index name
                            column_json->>'data_space',
                            entity_developer_name, -- Actual table name
                            dev_name -- Actual column name
                        );
                END CASE;

                IF item ? 'is_standard'
                AND (item->>'is_standard') IS NOT NULL
                AND (item->>'is_standard') <> ''
                AND (item->>'is_standard')::boolean = true THEN
                    --Inserting into column_meta table
                    INSERT INTO production.column_meta (
                        label, entity_id, developer_name, data_type, pg_data_type, is_deletable, created_by, last_modified_by
                    )
                    VALUES (
                        item->>'label',
                        item->>'entity_id',
                        dev_name,
                        item->>'data_type',
                        'varchar(22)',
                        false,
                        current_user_id,
                        current_user_id

                    )
                    RETURNING column_id INTO inserted_column_id;
                ELSE
                    --Inserting into column_meta table
                    INSERT INTO production.column_meta (
                        label, entity_id, developer_name, data_type, pg_data_type, is_deletable, created_by, last_modified_by,description
                    )
                    VALUES (
                        item->>'label',
                        item->>'entity_id',
                        dev_name,
                        item->>'data_type',
                        'varchar(22)',
                        true,
                        current_user_id,
                        current_user_id,
                        item->>'description'
                    )
                    RETURNING column_id INTO inserted_column_id;

                END IF;

                RAISE NOTICE 'Column Id; %',inserted_column_id;

                --Now Inserting into the lookup_meta table
                INSERT INTO production.lookup_meta(
                    entity_id, column_id, entity_prefix, parent_id, created_by, last_modified_by, description
                )
                VALUES(
                    item->>'entity_id',
                    inserted_column_id,
                    entity_prefix,
                    item->>'parent_entity_id',
                    item->>'created_by',
                    item->>'last_modified_by',
                    item->>'description'
                );
            ELSIF item->>'data_type' = 'master' THEN
                -- Ensuring accessible is set to true
                is_accessible := true;
                -- Ensure parent_entity_id is provided for relationships
                IF NOT item ? 'parent_entity_id' THEN
                    RETURN production.get_response_message(
  jsonb_build_object(
    'data', jsonb_build_array(jsonb_build_object('error_code', '1103'))
  )
);
   -- parent_entity_id is required for lookup fields!
                END IF;

                --Ensuring Ids are not same
                IF item->>'entity_id' = item->>'parent_entity_id' THEN
                   RETURN production.get_response_message(
  jsonb_build_object(
    'data', jsonb_build_array(jsonb_build_object('error_code', '1105'))
  )
);
   -- parent_entity_id & entity_id cannot be same
                END IF;

                -- Fetch parent entity developer name
                SELECT developer_name INTO parent_entity_developer_name
                FROM production.entity_meta
                WHERE entity_id = item->>'parent_entity_id';
                -- Define foreign key constraint name
                fk_constraint_name := format('fk_%I_%I', entity_developer_name,  dev_name);

                -- Add column
                EXECUTE format(
                    'ALTER TABLE %I.%I ADD COLUMN %I varchar(22) NOT NULL;',
                    column_json->>'data_space',
                    entity_developer_name, -- Actual table name
                    dev_name -- Actual column name
                );

                -- Add foreign key constraint
                EXECUTE format(
                    'ALTER TABLE %I.%I ADD CONSTRAINT %I FOREIGN KEY (%I) REFERENCES %I.%I(%I_id) ON DELETE CASCADE;',
                    column_json->>'data_space',
                    entity_developer_name, -- Actual table name
                    fk_constraint_name,
                    dev_name, -- Actual column name
                    column_json->>'data_space',
                    parent_entity_developer_name, -- Actual parent table name
                    parent_entity_developer_name, -- Used for parent_table_name_id
                    parent_entity_developer_name
                );

                -- Create index for performance
                EXECUTE format(
                    'CREATE INDEX %I ON %I.%I(%I);',
                    format('idx_%I_%I', entity_developer_name, dev_name), -- Dynamically created index name
                    column_json->>'data_space',
                    entity_developer_name, -- Actual table name
                    dev_name -- Actual column name
                );

                --Inserting into column_meta table
                INSERT INTO production.column_meta (
                    label, entity_id, developer_name, data_type, pg_data_type, is_deletable, created_by, last_modified_by,description
                )
                VALUES (
                    item->>'label',
                    item->>'entity_id',
                    dev_name,
                    item->>'data_type',
                    'varchar(22)',
                    true,
                    current_user_id,
                    current_user_id,
                    item->>'description'
                )
                RETURNING column_id INTO inserted_column_id;


                RAISE NOTICE 'Column Id; %',inserted_column_id;

                --Now Inserting into the lookup_meta table
                INSERT INTO production.lookup_meta(
                    entity_id, column_id, entity_prefix, parent_id, created_by, last_modified_by,description
                )
                VALUES(
                    item->>'entity_id',
                    inserted_column_id,
                    entity_prefix,
                    item->>'parent_entity_id',
                    item->>'created_by',
                    item->>'last_modified_by',
                    item->>'description'
                );
            ELSIF item->>'data_type' = 'checkbox' THEN
                -- Ensuring accessible is set to true
                is_accessible := true;
                EXECUTE format(
                    'ALTER TABLE %I.%I ADD COLUMN %I boolean %s;',
                    column_json->>'data_space',
                    entity_developer_name, -- Actual table name
                    dev_name, -- Actual column name
                    CASE WHEN (item->>'required')::BOOLEAN THEN 'NOT NULL' ELSE 'NULL' END
                );

                --Inserting into column_meta
                INSERT INTO production.column_meta (
                    label, entity_id, developer_name, data_type, pg_data_type, required, boolean_value, is_deletable, created_by, last_modified_by,description
                )
                VALUES (
                    item->>'label',
                    item->>'entity_id',
                    dev_name,
                    item->>'data_type',
                    'boolean',
                    (item->>'required')::BOOLEAN,
                    (item->>'boolean_value')::BOOLEAN,
                    true,
                    current_user_id,
                    current_user_id,
                    item->>'description'
                )
                RETURNING column_id INTO inserted_column_id;
            ELSIF item->>'data_type' = 'time' THEN
                -- Ensuring accessible is set to true
                is_accessible := true;
                --Step 1: Add the timestamp column with DEFAULT CURRENT_TIMESTAMP
                EXECUTE format(
                    'ALTER TABLE %I.%I ADD COLUMN IF NOT EXISTS %I time without time zone %s;',
                    column_json->>'data_space',
                    entity_developer_name, -- Actual table name
                    dev_name, -- Actual column name
                    CASE WHEN (item->>'required')::BOOLEAN THEN 'NOT NULL' ELSE 'NULL' END
                );

                --Inserting into column_meta
                INSERT INTO production.column_meta (
                    label, entity_id, developer_name, data_type, pg_data_type, required, is_deletable, created_by, last_modified_by,description
                )
                VALUES (
                    item->>'label',
                    item->>'entity_id',
                    dev_name,
                    item->>'data_type',
                    'time without time zone',
                    (item->>'required')::BOOLEAN,
                    true,
                    current_user_id,
                    current_user_id,
                    item->>'description'
                )
                RETURNING column_id INTO inserted_column_id;
            ELSIF item->>'data_type' = 'date' THEN
                -- Ensuring accessible is set to true
                is_accessible := true;
                EXECUTE format(
                    'ALTER TABLE %I.%I ADD COLUMN %I date %s;',
                    column_json->>'data_space',
                    entity_developer_name, -- Actual table name
                    dev_name, -- Actual column name
                    CASE WHEN (item->>'required')::BOOLEAN THEN 'NOT NULL' ELSE 'NULL' END
                );

                --Inserting into column_meta
                INSERT INTO production.column_meta (
                    label, entity_id, developer_name, data_type, pg_data_type, required, is_deletable, created_by, last_modified_by,description
                )
                VALUES (
                    item->>'label',
                    item->>'entity_id',
                    dev_name,
                    item->>'data_type',
                    'date',
                    (item->>'required')::BOOLEAN,
                    true,
                    current_user_id,
                    current_user_id,
                    item->>'description'
                )
                RETURNING column_id INTO inserted_column_id;
            ELSIF item->>'data_type' = 'date_time' THEN

                -- Ensuring accessible is set to true
                is_accessible := true;

                --Step 1: Add the timestamp column with DEFAULT CURRENT_TIMESTAMP
                EXECUTE format(
                    'ALTER TABLE %I.%I ADD COLUMN IF NOT EXISTS %I timestamptz %s DEFAULT CURRENT_TIMESTAMP;',
                    column_json->>'data_space',
                    entity_developer_name, -- Actual table name
                    dev_name, -- Actual column name
                    CASE WHEN (item->>'required')::BOOLEAN THEN 'NOT NULL' ELSE 'NULL' END
                );

                IF item ? 'is_standard'
                AND (item->>'is_standard') IS NOT NULL
                AND (item->>'is_standard') <> ''
                AND (item->>'is_standard')::boolean = true THEN
                    --Inserting into column_meta
                    INSERT INTO production.column_meta (
                        label, entity_id, developer_name, data_type, pg_data_type, is_deletable, required, created_by, last_modified_by,description
                    )
                    VALUES (
                        item->>'label',
                        item->>'entity_id',
                        dev_name,
                        item->>'data_type',
                        'timestamptz',
                        true,
                        (item->>'required')::BOOLEAN,
                        current_user_id,
                        current_user_id,
                        item->>'description'

                    )
                    RETURNING column_id INTO inserted_column_id;
                ELSE
                    --Inserting into column_meta
                    INSERT INTO production.column_meta (
                        label, entity_id, developer_name, data_type, pg_data_type, is_deletable, required, created_by, last_modified_by,description
                    )
                    VALUES (
                        item->>'label',
                        item->>'entity_id',
                        dev_name,
                        item->>'data_type',
                        'timestamptz',
                        false,
                        (item->>'required')::BOOLEAN,
                        current_user_id,
                        current_user_id,
                        item->>'description'
                    )
                    RETURNING column_id INTO inserted_column_id;

                END IF;

            ELSIF item->>'data_type' = 'email' THEN
                -- Ensuring accessible is set to true
                is_accessible := true;

                EXECUTE format(
                    'ALTER TABLE %I.%I ADD COLUMN %I varchar(255) %s;',
                    column_json->>'data_space',
                    entity_developer_name, -- Actual table name
                    dev_name, -- Actual column name
                    CASE WHEN (item->>'required')::BOOLEAN THEN 'NOT NULL' ELSE 'NULL' END
                );
                --Inserting into column_meta
                INSERT INTO production.column_meta (
                    label, entity_id, developer_name, data_type, pg_data_type, required, is_deletable, created_by, last_modified_by,description
                )
                VALUES (
                    item->>'label',
                    item->>'entity_id',
                    dev_name,
                    item->>'data_type',
                    'varchar(255)',
                    (item->>'required')::BOOLEAN,
                    true,
                    current_user_id,
                    current_user_id,
                    item->>'description'
                )
                RETURNING column_id INTO inserted_column_id;
            ELSIF item->>'data_type' = 'phone' THEN
                -- Ensuring accessible is set to true
                is_accessible := true;

                RAISE NOTICE 'Entered in Phone data type %',  dev_name;
                EXECUTE format(
                    'ALTER TABLE %I.%I ADD COLUMN %I varchar(20) %s;',
                    column_json->>'data_space',
                    entity_developer_name, -- Actual table name
                    dev_name, -- Actual column name
                    CASE WHEN (item->>'required')::BOOLEAN THEN 'NOT NULL' ELSE 'NULL' END
                );

                --Inserting into column_meta
                INSERT INTO production.column_meta (
                    label, entity_id, developer_name, data_type, pg_data_type, required, is_deletable, created_by, last_modified_by , description
                )
                VALUES (
                    item->>'label',
                    item->>'entity_id',
                    dev_name,
                    item->>'data_type',
                    'varchar(20)',
                    (item->>'required')::BOOLEAN,
                    true,
                    current_user_id,
                    current_user_id,
                    item->>'description'
                )
                RETURNING column_id INTO inserted_column_id;
            ELSIF item->>'data_type' IN ('picklist', 'multi_picklist') THEN
                -- Ensuring accessible is set to true
                is_accessible := true;
                -- Check if it's a multi-picklist
                IF item->>'data_type' = 'multi_picklist' THEN
                    -- Alter table to add multi-picklist column
                    EXECUTE format(
                        'ALTER TABLE %I.%I ADD COLUMN %I VARCHAR(22) %s;',
                        column_json->>'data_space',
                        entity_developer_name, -- Actual table name
                        dev_name, -- Actual column name
                        CASE WHEN (item->>'required')::BOOLEAN THEN 'NOT NULL' ELSE 'NULL' END
                    );

                    -- Insert into column_meta and return column_id
                    INSERT INTO production.column_meta (
                        label, entity_id, developer_name, data_type, pg_data_type, picklist, required, is_deletable, created_by, last_modified_by,description
                    )
                    VALUES (
                        item->>'label',
                        item->>'entity_id',
                        dev_name,
                        item->>'data_type',
                        'varchar(22)',
                        (item->>'multi_picklist')::BOOLEAN,
                        (item->>'required')::BOOLEAN,
                        true,
                        current_user_id,
                        current_user_id,
                        item->>'description'
                    )
                    RETURNING column_id INTO inserted_column_id;

                    RAISE NOTICE 'Multi-Picklist Column ID: %', inserted_column_id;

                ELSE
                    -- Alter table to add picklist column
                    EXECUTE format(
                        'ALTER TABLE %I.%I ADD COLUMN %I VARCHAR(22) %s;',
                        column_json->>'data_space',
                        entity_developer_name, -- Actual table name
                        dev_name, -- Actual column name
                        CASE WHEN (item->>'required')::BOOLEAN THEN 'NOT NULL' ELSE 'NULL' END
                    );

                    -- Insert into column_meta and return column_id
                    INSERT INTO production.column_meta (
                        label, entity_id, developer_name, data_type, pg_data_type, picklist, required, is_deletable, created_by, last_modified_by , description
                    )
                    VALUES (
                        item->>'label',
                        item->>'entity_id',
                        dev_name,
                        item->>'data_type',
                        'varchar(22)',
                        (item->>'picklist')::BOOLEAN,
                        (item->>'required')::BOOLEAN,
                        true,
                        current_user_id,
                        current_user_id,
                        item->>'description'
                    )
                    RETURNING column_id INTO inserted_column_id;

                    RAISE NOTICE 'Picklist Column ID: %', inserted_column_id;
                END IF;

            --Used Picklist Master and Picklist Info Approach to Insert picklist values for both picklist and multi-picklist

                    INSERT INTO production.picklist_meta (
                        column_id, developer_name, label, status, "default",
                        created_by, last_modified_by, description
                    )
                    VALUES (
                        inserted_column_id,
                        dev_name,
                        item->>'label',
                        'Active',
                        (item->>'required')::BOOLEAN,
                        current_user_id,
                        current_user_id,
                        item->>'description'
                    )
                    RETURNING picklist_id INTO v_picklist_id;   -- ← now unambiguous

                    -- 3c) loop and insert each picklist value
                    FOR picklist_entry IN
                      SELECT jsonb_array_elements(item->'picklist_values')
                    LOOP
                      INSERT INTO production.picklist_value_master (
                          picklist_id, developer_name, label, status, "default",
                          sort_order, created_date, last_modified_date,
                          created_by, last_modified_by, description
                      ) VALUES (
                          v_picklist_id,   -- ← clearly your variable, not the column
                          picklist_entry->>'value_developer_name',
                          picklist_entry->>'value',
                          picklist_entry->>'status',
                          (picklist_entry->>'default')::BOOLEAN,
                          COALESCE((picklist_entry->>'sort_order')::INT, 0),
                          CURRENT_TIMESTAMP,
                          CURRENT_TIMESTAMP,
                          current_user_id,
                          current_user_id,
                          item->>'description'
                      );
                    END LOOP;


            ELSIF item->>'data_type' = 'url' THEN
                -- Ensuring accessible is set to true
                is_accessible := true;

                EXECUTE format(
                    'ALTER TABLE %I.%I ADD COLUMN %I varchar(255) %s;',
                    column_json->>'data_space',
                    entity_developer_name, -- Actual table name
                    dev_name, -- Actual column name
                    CASE WHEN (item->>'required')::BOOLEAN THEN 'NOT NULL' ELSE 'NULL' END
                );

                --Inserting into column_meta
                INSERT INTO production.column_meta (
                    label, entity_id, developer_name, data_type, pg_data_type, required, is_deletable, created_by, last_modified_by, description
                )
                VALUES (
                    item->>'label',
                    item->>'entity_id',
                    dev_name,
                    item->>'data_type',
                    'varchar(255)',
                    (item->>'required')::BOOLEAN,
                    true,
                    current_user_id,
                    current_user_id,
                    item->>'description'
                )
                RETURNING column_id INTO inserted_column_id;
            ELSIF item->>'data_type' = 'currency' THEN
                -- Ensuring accessible is set to true
                is_accessible := true;

                pg_data_type := format('numeric(%s,%s)', (item->>'integer')::INTEGER, (item->>'decimal')::INTEGER);
                EXECUTE format(
                    'ALTER TABLE %I.%I ADD COLUMN %I numeric(%s,%s) %s;',
                    column_json->>'data_space',
                    entity_developer_name, -- Actual table name
                    dev_name, -- Actual column name
                    (item->>'integer')::INTEGER, (item->>'decimal')::INTEGER,
                    CASE WHEN (item->>'required')::BOOLEAN THEN 'NOT NULL' ELSE 'NULL' END
                );

                --Inserting into column_meta
                INSERT INTO production.column_meta (
                    label, entity_id, developer_name, length, data_type, pg_data_type, required, "unique", "integer", "decimal", is_deletable, created_by, last_modified_by,description
                )
                VALUES (
                    item->>'label',
                    item->>'entity_id',
                    dev_name,
                    (item->>'length')::INTEGER,
                    item->>'data_type',
                    pg_data_type,
                    (item->>'required')::BOOLEAN,
                    (item->>'unique')::BOOLEAN,
                    (item->>'integer')::INTEGER,
                    (item->>'decimal')::INTEGER,
                    true,
                    current_user_id,
                    current_user_id,
                    item->>'description'

                )
                RETURNING column_id INTO inserted_column_id;
            ELSIF item->>'data_type' = 'number' THEN
                -- Ensuring accessible is set to true
                is_accessible := true;

                pg_data_type := format('numeric(%s,%s)', (item->>'integer')::INTEGER, (item->>'decimal')::INTEGER);
                EXECUTE format(
                    'ALTER TABLE %I.%I ADD COLUMN %I numeric(%s,%s) %s;',
                    column_json->>'data_space',
                    entity_developer_name, -- Actual table name
                    dev_name, -- Actual column name
                    (item->>'integer')::INTEGER, (item->>'decimal')::INTEGER,
                    CASE WHEN (item->>'required')::BOOLEAN THEN 'NOT NULL' ELSE 'NULL' END
                );

                --Inserting into column_meta
                INSERT INTO production.column_meta (
                    label, entity_id, developer_name, length, data_type, pg_data_type, required, "unique", "integer", "decimal", is_deletable, created_by, last_modified_by,description
                )
                VALUES (
                    item->>'label',
                    item->>'entity_id',
                    dev_name,
                    (item->>'length')::INTEGER,
                    item->>'data_type',
                    pg_data_type,
                    (item->>'required')::BOOLEAN,
                    (item->>'unique')::BOOLEAN,
                    (item->>'integer')::INTEGER,
                    (item->>'decimal')::INTEGER,
                    true,
                    current_user_id,
                    current_user_id,
                    item->>'description'
                )
                RETURNING column_id INTO inserted_column_id;
           ELSIF item->>'data_type' = 'percent' THEN
    -- Ensuring accessible is set to true
    is_accessible := true;

    pg_data_type := format('numeric(%s,%s)', (item->>'integer')::INTEGER, (item->>'decimal')::INTEGER);
    EXECUTE format(
        'ALTER TABLE %I.%I ADD COLUMN %I numeric(%s,%s) %s;',
        column_json->>'data_space',
        entity_developer_name, -- Actual table name
        dev_name, -- Actual column name
        (item->>'integer')::INTEGER, (item->>'decimal')::INTEGER,
        CASE WHEN (item->>'required')::BOOLEAN THEN 'NOT NULL' ELSE 'NULL' END
    );

    --Inserting into column_meta
    INSERT INTO production.column_meta (
        label, entity_id, developer_name, length, data_type, pg_data_type, required, "unique", "integer", "decimal", is_deletable, created_by, last_modified_by, description
    )
    VALUES (
        item->>'label',
        item->>'entity_id',
        dev_name,
        -- Safely extract 'length', providing NULL if not present in the JSON
        CASE WHEN item ? 'length' THEN (item->>'length')::INTEGER ELSE NULL END,
        item->>'data_type',
        pg_data_type,
        (item->>'required')::BOOLEAN,
        (item->>'unique')::BOOLEAN,
        (item->>'integer')::INTEGER,
        (item->>'decimal')::INTEGER,
        true,
        current_user_id,
        current_user_id,
        item->>'description' -- Added the missing description value
    )
    RETURNING column_id INTO inserted_column_id;
            ELSIF item->>'data_type' = 'geolocation' THEN
                -- Ensuring accessible is set to true
                is_accessible := true;

                EXECUTE format(
                    'ALTER TABLE %I.%I ADD COLUMN %I POINT;',
                    column_json->>'data_space',
                    entity_developer_name, -- Actual table name
                    dev_name -- Actual column name
                );

                --Inserting into column_meta
                INSERT INTO production.column_meta (
                    label, entity_id, developer_name, data_type, pg_data_type, required, is_deletable, created_by, last_modified_by,description
                )
                VALUES (
                    item->>'label',
                    item->>'entity_id',
                    dev_name,
                    item->>'data_type',
                    'POINT',
                    (item->>'required')::BOOLEAN,
                    true,
                    current_user_id,
                    current_user_id,
                    item->>'description'
                )
                RETURNING column_id INTO inserted_column_id;
            ELSIF item->>'data_type' = 'text' THEN
                -- Ensuring accessible is set to true
                is_accessible := true;

                pg_data_type := format('varchar(%s)', item->>'length');

                EXECUTE format(
                    'ALTER TABLE %I.%I ADD COLUMN %I varchar(%s) %s;',
                    column_json->>'data_space',
                    entity_developer_name, -- Actual table name
                    dev_name, -- Actual column name
                    (item->>'length')::INTEGER, CASE WHEN (item->>'required')::BOOLEAN THEN 'NOT NULL' ELSE 'NULL' END
                );
                --Inserting into column_meta
                INSERT INTO production.column_meta (
                    label, entity_id, developer_name, length, data_type, pg_data_type, required, "unique", is_deletable, created_by, last_modified_by,description
                )
                VALUES (
                    item->>'label',
                    item->>'entity_id',
                    dev_name,
                    (item->>'length')::INTEGER,
                    item->>'data_type',
                    pg_data_type,
                    (item->>'required')::BOOLEAN,
                    (item->>'unique')::BOOLEAN,
                    true,
                    current_user_id,
                    current_user_id,
                    item->>'description'
                )
                RETURNING column_id INTO inserted_column_id;
            ELSIF item->>'data_type' = 'text_area' THEN
                -- Ensuring accessible is set to true
                is_accessible := true;

                EXECUTE format(
                    'ALTER TABLE %I.%I ADD COLUMN %I varchar(255);',
                    column_json->>'data_space',
                    entity_developer_name, -- Actual table name
                    dev_name -- Actual column name
                );
                --Inserting into column_meta
                INSERT INTO production.column_meta (
                    label, entity_id, developer_name, length, data_type, pg_data_type, required, is_deletable, created_by, last_modified_by,description
                )
                VALUES (
                    item->>'label',
                    item->>'entity_id',
                    dev_name,
                    255,
                    item->>'data_type',
                    'varchar(255)',
                    (item->>'required')::BOOLEAN,
                    true,
                    current_user_id,
                    current_user_id,
                    item->>'description'
                )
                RETURNING column_id INTO inserted_column_id;
            ELSIF item->>'data_type' = 'text_area_long' THEN
                -- Ensuring accessible is set to true
                is_accessible := true;

                pg_data_type := format('varchar(%s)', item->>'length');

                EXECUTE format(
                    'ALTER TABLE %I.%I ADD COLUMN %I varchar(%s);',
                    column_json->>'data_space',
                    entity_developer_name, -- Actual table name
                    dev_name, -- Actual column name
                    (item->>'length')::INTEGER
                );
                RAISE NOTICE 'text area long created % ', item->>'label';
                --Inserting into column_meta
                INSERT INTO production.column_meta (
                    label, entity_id, developer_name, length, data_type, pg_data_type, is_deletable, created_by, last_modified_by,description
                )
                VALUES (
                    item->>'label',
                    item->>'entity_id',
                    dev_name,
                    (item->>'length')::INTEGER,
                    item->>'data_type',
                    pg_data_type,
                    true,
                    current_user_id,
                    current_user_id,
                    item->>'description'
                )
                RETURNING column_id INTO inserted_column_id;
            ELSIF item->>'data_type' = 'text_area_rich' THEN
                -- Ensuring accessible is set to true
                is_accessible := true;

                pg_data_type := format('varchar(%s)', item->>'length');

                EXECUTE format(
                    'ALTER TABLE %I.%I ADD COLUMN %I varchar(%s);',
                    column_json->>'data_space',
                    entity_developer_name, -- Actual table name
                    dev_name, -- Actual column name
                    (item->>'length')::INTEGER
                );
                --Inserting into column_meta
                INSERT INTO production.column_meta (
                    label, entity_id, developer_name, length, data_type, pg_data_type, is_deletable, created_by, last_modified_by,description
                )
                VALUES (
                    item->>'label',
                    item->>'entity_id',
                    dev_name,
                    (item->>'length')::INTEGER,
                    item->>'data_type',
                    pg_data_type,
                    true,
                    current_user_id,
                    current_user_id,
                    item->>'description'
                )
                RETURNING column_id INTO inserted_column_id;
            ELSEIF item->>'data_type' = 'auto_number' THEN
                -- Ensuring accessible is set to true
                is_accessible := true;

                -- Create sequence dynamically with user-defined or default start number
                EXECUTE format(
                    'CREATE SEQUENCE IF NOT EXISTS %I.%I START WITH %s',
                    column_json->>'data_space',
                    format('%I_sequence', dev_name), -- Quoted sequence name
                    COALESCE((item->>'starting_number')::INTEGER, 1)    -- Default to 1 if NULL
                );

                -- Reset sequence to ensure it starts from the given starting_number
                EXECUTE format(
                    'ALTER SEQUENCE %I.%I RESTART WITH %s',
                    column_json->>'data_space',
                    format('%I_sequence', dev_name), -- Quoted sequence name
                    COALESCE((item->>'starting_number')::INTEGER, 1)
                );

                -- Add column using DEFAULT (fixing syntax error)
                EXECUTE format(
                    'ALTER TABLE %I.%I ADD COLUMN IF NOT EXISTS %I VARCHAR(10) ' ||
                    'DEFAULT (%L || lpad(nextval(%L)::text, 5, ''0'')) NOT NULL',
                    column_json->>'data_space',
                    entity_developer_name, -- Actual table name
                    dev_name, -- Actual column name
                    item->>'auto_number_prefix',
                    format('%I.%I', column_json->>'data_space', format('%I_sequence', dev_name)) -- Quoted schema.sequence_name
                );

                --Inserting into column_meta
                INSERT INTO production.column_meta (
                    label, entity_id, developer_name, data_type, pg_data_type, is_deletable, created_by, last_modified_by,description
                )
                VALUES (
                    item->>'label',
                    item->>'entity_id',
                    dev_name,
                    item->>'data_type',
                    'varchar(10)',
                    true,
                    current_user_id,
                    current_user_id,
                    item->>'description'
                )
                RETURNING column_id INTO inserted_column_id;
            ELSE
                -- Ensuring accessible is set to true
                is_accessible := true;

                EXECUTE format(
                    'ALTER TABLE %I.%I ADD COLUMN %I varchar(255);',
                    column_json->>'data_space',
                    entity_developer_name, -- Actual table name
                    dev_name -- Actual column name
                );

                --Inserting into column_meta
                INSERT INTO production.column_meta (
                    label, entity_id, developer_name, data_type, pg_data_type, is_deletable, created_by, last_modified_by,description
                )
                VALUES (
                    item->>'label',
                    item->>'entity_id',
                    dev_name,
                    item->>'data_type',
                    'varchar(255)',
                    true,
                    current_user_id,
                    current_user_id,
                    item->>'description'
                )
                RETURNING column_id INTO inserted_column_id;
            END IF;

            RAISE NOTICE 'Column "%" added to table "%"',  dev_name, entity_developer_name;
        ELSE
            RETURN production.get_response_message(
  jsonb_build_object(
    'data', jsonb_build_array(jsonb_build_object('error_code', '1106'))
  )
);
  -- Column already exists
        END IF;

    -- Get the privilege_id for 'manage_entities'
    SELECT privilege_id INTO inserting_privilege_id
    FROM production.privilege_meta
    WHERE developer_name = 'manage_fields';
          -- Grant column privileges using the new function
        IF is_accessible THEN
            -- Determine access_level based on data_type (1: Read, 3: Read/Write)
            IF item->>'data_type' = 'id' THEN
                current_access_level := 1; -- Read-only access
            ELSE
                current_access_level := 3; -- Read/Write access (or a suitable default)
            END IF;

            -- Assuming a function `grant_column_privileges` exists
            PERFORM production.grant_column_privileges_with_bitmask(jsonb_build_object(
                'data_space', column_json->>'data_space',
                'active_session', column_json->'active_session',
                'data', jsonb_build_array(
                    jsonb_build_object(
                        'entity_id', item->>'entity_id',
                        'column_id', inserted_column_id,
                        'bitmask', current_access_level
                    )
                )
            ));
        END IF;
    END LOOP;
    RETURN jsonb_build_object('Sucess', '2007', 'message', 'Column created successfully');
END;
$function$
;
