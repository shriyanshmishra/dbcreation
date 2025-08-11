-- DROP FUNCTION production.create_data_table_function(jsonb, text, text, varchar, text);

CREATE OR REPLACE FUNCTION production.create_data_table_function(item jsonb, data_space text, meta_table text, user_id character varying, session_id text)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
    inserted_entity_id varchar(22);
    key_column_name text;
    id_column_name text;
    full_table_name text;
    inserting_privilege_id varchar(22);
    dev_name varchar(255);
BEGIN
    dev_name := production.remove_special_characters(item->>'developer_name'); 

    RAISE NOTICE 'Table % Creation Initilated: % , %', item->>'label', data_space, dev_name;

    -- Create empty data table with an id column
    EXECUTE FORMAT(
        'CREATE TABLE IF NOT EXISTS %I.%I ()',
        data_space,
        dev_name
    );

    -- Construct the full table name
    full_table_name := format('%I.%I', data_space , meta_table);

    RAISE NOTICE 'Table % created full_table_name: ', full_table_name;

    -- Insert into entity meta table
    EXECUTE format('
        INSERT INTO %s (
            label, plural_label, developer_name, prefix, 
            allow_reports, allow_activities, track_field_history, allow_sharing, 
            in_development, deployed, data_space, last_modified_by, created_by,
            description, package_name, package_prefix
        ) VALUES (
            $1, $2, $3, $4, 
            $5::BOOLEAN, $6::BOOLEAN, $7::BOOLEAN, $8::BOOLEAN, 
            $9::BOOLEAN, $10::BOOLEAN, $11, $12, $13,
            $14, $15, $16
        ) RETURNING entity_id', full_table_name)
    INTO inserted_entity_id
    USING 
        item->>'label',
        item->>'plural_label',
        dev_name,
        item->>'prefix',
        (item->>'allow_reports'),
        (item->>'allow_activities'),
        (item->>'track_field_history'),
        (item->>'allow_sharing'),
        (item->>'in_development'),
        (item->>'deployed'),
        data_space,
        user_id,
        user_id,
        item->>'description',
        COALESCE(item->>'package_name', 'Default'),
        COALESCE(item->>'package_prefix', 'DEF');

    RAISE NOTICE 'Table % created successfully', item->>'label';

    -- Get the privilege_id for 'manage_entities'
    SELECT privilege_id INTO inserting_privilege_id
    FROM production.privilege_meta
    WHERE developer_name = 'manage_entities';

    -- Insert initial entry into entity_privilege_meta (just as reference)
    INSERT INTO production.entity_privilege_meta (
        privilege_id,
        entity_id,
        access_level,
        created_by,
        last_modified_by
    )
    VALUES (
        inserting_privilege_id,
        inserted_entity_id,
        '3',  -- bitmask 3 = READ + CREATE
        user_id,
        user_id
    );

    RAISE NOTICE 'Given access for entity % to this User: %', dev_name, user_id;

    -- Create default columns
    PERFORM production.create_data_table_default_columns_function(
        item::jsonb, data_space, meta_table, inserted_entity_id, user_id, session_id
    );

    RAISE NOTICE 'Default Column % Creation successful', item->>'label';

    -- Grant entity privileges to the user using the grant_entity_privileges function
    PERFORM production.grant_entity_privileges(jsonb_build_object(
        'data_space', data_space,
        'active_session', jsonb_build_object('session_token', session_id),
        'data', jsonb_build_array(
            jsonb_build_object(
                'entity_id', inserted_entity_id,
                'bitmask', 3  -- Grant READ + CREATE privileges
            )
        )
    ));

    RETURN inserted_entity_id;
END;
$function$
;
