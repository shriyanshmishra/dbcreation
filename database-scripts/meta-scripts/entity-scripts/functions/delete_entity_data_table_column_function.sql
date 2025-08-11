-- DROP FUNCTION production.delete_entity_data_table_column_function(jsonb);

CREATE OR REPLACE FUNCTION production.delete_entity_data_table_column_function(json_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    record JSONB;
    protected_columns TEXT[] := ARRAY[
        'developer_name', 'owner_id', 'last_modified_by',
        'last_modified_date', 'name', 'data_type',
        'lookup', 'key_column_dev_name'
    ];
BEGIN
    FOR record IN SELECT * FROM jsonb_array_elements(json_input -> 'data')
    LOOP
        -- Return error if trying to delete a protected column
        IF (record->>'developer_name') = ANY(protected_columns) THEN
            RETURN production.get_response_message(
                jsonb_build_object(
                    'data', jsonb_build_array(jsonb_build_object('error_code', '1113'))
                )
            );
        END IF;

        -- Drop the column from the entity's table
        EXECUTE format(
            'ALTER TABLE %I.%I DROP COLUMN IF EXISTS %I CASCADE',
            json_input ->> 'data_space',
            (SELECT developer_name FROM production.entity_meta WHERE entity_id = json_input ->> 'entity_id'),
            record ->> 'developer_name'
        );

        -- Delete the metadata from column_meta
        DELETE FROM production.column_meta
        WHERE column_id = (record->>'column_id')::text
        AND entity_id = (json_input ->> 'entity_id')::text;

    END LOOP;

    RETURN NULL; -- success, no errors
END;
$function$
;
