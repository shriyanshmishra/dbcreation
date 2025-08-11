CREATE OR REPLACE FUNCTION production.update_entity_data_table_function(data_space text, old_dev_name text, new_dev_name text)
RETURNS text
LANGUAGE plpgsql
AS $function$
DECLARE
    pk_column text;
    index_columns text[] := ARRAY['created_by', 'last_modified_by', 'owner_id', 'created_date', 'last_modified_date'];
    idx_col text;
BEGIN
    IF old_dev_name IS DISTINCT FROM new_dev_name THEN
        -- Rename data table
        EXECUTE format('ALTER TABLE %I.%I RENAME TO %I;',
            data_space, old_dev_name, new_dev_name);

        -- Rename columns in the data table
        EXECUTE format('ALTER TABLE %I.%I RENAME COLUMN %I TO %I;',
            data_space, new_dev_name,
            old_dev_name || '_key', new_dev_name || '_key');

        EXECUTE format('ALTER TABLE %I.%I RENAME COLUMN %I TO %I;',
            data_space, new_dev_name,
            old_dev_name || '_id', new_dev_name || '_id');

        -- Rename the sequence used in the _key column
        EXECUTE format(
            'ALTER SEQUENCE IF EXISTS %I.%I_%I_key_seq RENAME TO %I_%I_key_seq;',
            data_space, old_dev_name, old_dev_name,
            new_dev_name, new_dev_name
        );

        -- Update the default value of the _key column to use the renamed sequence
        EXECUTE format(
            'ALTER TABLE %I.%I ALTER COLUMN %I_key SET DEFAULT nextval(''%I.%I_%I_key_seq''::regclass);',
            data_space, new_dev_name,
            new_dev_name,
            data_space, new_dev_name, new_dev_name
        );

        -- Define the primary key column
        pk_column := new_dev_name || '_id';

        -- Drop and recreate primary key constraint
        EXECUTE format('ALTER TABLE %I.%I DROP CONSTRAINT IF EXISTS %I;',
            data_space, new_dev_name, 'pk_' || old_dev_name);

        EXECUTE format('ALTER TABLE %I.%I ADD CONSTRAINT %I PRIMARY KEY (%I);',
            data_space, new_dev_name, 'pk_' || new_dev_name, pk_column);

        -- Rename foreign key constraints
        EXECUTE format('ALTER TABLE %I.%I RENAME CONSTRAINT fk_%I_created_by TO fk_%I_created_by;',
            data_space, new_dev_name, old_dev_name, new_dev_name);

        EXECUTE format('ALTER TABLE %I.%I RENAME CONSTRAINT fk_%I_last_modified_by TO fk_%I_last_modified_by;',
            data_space, new_dev_name, old_dev_name, new_dev_name);

        EXECUTE format('ALTER TABLE %I.%I RENAME CONSTRAINT fk_%I_owner_id TO fk_%I_owner_id;',
            data_space, new_dev_name, old_dev_name, new_dev_name);

        -- Drop and recreate indexes for created_by, last_modified_by, owner_id
        FOREACH idx_col IN ARRAY index_columns
        LOOP
            EXECUTE format(
                'DROP INDEX IF EXISTS %I.%I;',
                data_space, 'idx_' || old_dev_name || '_' || idx_col
            );

            EXECUTE format(
                'CREATE INDEX %I ON %I.%I (%I);',
                'idx_' || new_dev_name || '_' || idx_col,
                data_space, new_dev_name, idx_col
            );
        END LOOP;

        -- Drop and recreate index for ID column
        EXECUTE format(
            'DROP INDEX IF EXISTS %I.%I;',
            data_space, 'idx_' || old_dev_name || '_id'
        );

        EXECUTE format(
            'CREATE INDEX %I ON %I.%I (%I);',
            'idx_' || new_dev_name || '_id',
            data_space, new_dev_name, pk_column
        );
    END IF;

    RETURN 'Entity table schema update completed successfully.';
END;
$function$
;