CREATE OR REPLACE FUNCTION production.update_entity_share_table_function(
    data_space text, old_dev_name text, new_dev_name text
)
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
    suffix text;
    index_columns text[] := ARRAY['created_by', 'last_modified_by', 'created_date', 'last_modified_date'];
    idx_col text;
BEGIN
    -- Check if developer_name has changed
    IF old_dev_name IS DISTINCT FROM new_dev_name THEN
        -- Rename share table
        EXECUTE format('ALTER TABLE %I.%I_share RENAME TO %I_share;', data_space, old_dev_name, new_dev_name);

        -- Rename columns in the share table
        EXECUTE format('ALTER TABLE %I.%I_share RENAME COLUMN %I TO %I;', 
            data_space, new_dev_name, 
            old_dev_name || '_share_key', new_dev_name || '_share_key');

        EXECUTE format('ALTER TABLE %I.%I_share RENAME COLUMN %I TO %I;', 
            data_space, new_dev_name, 
            old_dev_name || '_share_id', new_dev_name || '_share_id');

        -- Rename primary key constraint
        EXECUTE format('ALTER TABLE %I.%I_share RENAME CONSTRAINT pk_%I_share TO pk_%I_share;', 
            data_space, new_dev_name, old_dev_name, new_dev_name);

        -- Rename foreign key constraints
        EXECUTE format('ALTER TABLE %I.%I_share RENAME CONSTRAINT %I_share_created_by_fkey TO %I_share_created_by_fkey;', 
            data_space, new_dev_name, old_dev_name, new_dev_name);

        EXECUTE format('ALTER TABLE %I.%I_share RENAME CONSTRAINT %I_share_last_modified_by_fkey TO %I_share_last_modified_by_fkey;', 
            data_space, new_dev_name, old_dev_name, new_dev_name);

        EXECUTE format('ALTER TABLE %I.%I_share RENAME CONSTRAINT %I_share_user_id_fkey TO %I_share_user_id_fkey;', 
            data_space, new_dev_name, old_dev_name, new_dev_name);

        EXECUTE format('ALTER TABLE %I.%I_share RENAME CONSTRAINT %I_share_group_id_fkey TO %I_share_group_id_fkey;', 
            data_space, new_dev_name, old_dev_name, new_dev_name);

        -- Rename sequence for the share_key
        EXECUTE format(
            'ALTER SEQUENCE IF EXISTS %I.%I_share_%I_share_key_seq RENAME TO %I_share_%I_share_key_seq;',
            data_space, old_dev_name, old_dev_name,
            new_dev_name, new_dev_name
        );

        -- Rename CHECK constraints
        FOREACH suffix IN ARRAY ARRAY[
            'account_access_level', 'opportunity_access_level',
            'case_access_level', 'contact_access_level'
        ]
        LOOP
            BEGIN
                EXECUTE format(
                    'ALTER TABLE %I.%I_share RENAME CONSTRAINT %I_share_%s_check TO %I_share_%s_check;',
                    data_space, new_dev_name,
                    old_dev_name, suffix, new_dev_name, suffix
                );
            EXCEPTION WHEN OTHERS THEN
                -- Optional: log or ignore if constraint doesn't exist
                NULL;
            END;
        END LOOP;

        -- Drop and recreate indexes for columns
        FOREACH idx_col IN ARRAY index_columns
        LOOP
            EXECUTE format(
                'DROP INDEX IF EXISTS %I.%I;',
                data_space, 'idx_' || old_dev_name || '_share_' || idx_col
            );

            EXECUTE format(
                'CREATE INDEX %I ON %I.%I_share (%I);',
                'idx_' || new_dev_name || '_share_' || idx_col,
                data_space, new_dev_name, idx_col
            );
        END LOOP;

        -- Drop and recreate index for share_id column
        EXECUTE format(
            'DROP INDEX IF EXISTS %I.%I;',
            data_space, 'idx_' || old_dev_name || '_share_share_id'
        );

        EXECUTE format(
            'CREATE INDEX %I ON %I.%I_share (%I);',
            'idx_' || new_dev_name || '_share_share_id',
            data_space, new_dev_name, new_dev_name || '_share_id'
        );

        -- Drop and recreate index for ID column (entity share id)
        EXECUTE format(
            'DROP INDEX IF EXISTS %I.%I;',
            data_space, 'idx_' || old_dev_name || '_share_share_table_id'
        );

        EXECUTE format(
            'CREATE INDEX %I ON %I.%I_share (%I);',
            'idx_' || new_dev_name || '_share_share_table_id',
            data_space, new_dev_name, new_dev_name || '_share_id'
        );
    END IF;

    RETURN 'Entity share table schema update completed successfully.';
END;
$$;