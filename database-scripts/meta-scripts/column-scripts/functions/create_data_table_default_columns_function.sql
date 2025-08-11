-- DROP FUNCTION production.create_data_table_default_columns_function(jsonb, text, text, varchar, varchar, text);

CREATE OR REPLACE FUNCTION production.create_data_table_default_columns_function(item jsonb, data_space text, meta_table text, inserted_entity_id character varying, user_id character varying, session_token text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    key_column_dev_name text;
    id_column_dev_name text;
    key_column_label text;
    id_column_label text;
	column_json json;
	parent_entity_id varchar(22);
      dev_name varchar(255);
BEGIN
     dev_name := production.remove_special_characters(item->>'developer_name'); 

    -- Start Creating Column on the Empty Table Schema
    RAISE NOTICE 'Default column % entity creation initiated.', dev_name;

    -- Extract values from input JSON
	key_column_dev_name := dev_name  || '_key';
    id_column_dev_name := dev_name || '_id';

    key_column_label := item->>'label' || ' Key';
    id_column_label := item->>'label' || ' Id';
	
	
	--Getting the user table id
	SELECT entity_id INTO parent_entity_id
	FROM production.entity_meta WHERE developer_name = 'user';
	
    -- Dynamically build the columns JSON array (with explicit JSONB casting)
    column_json := jsonb_build_array(
        jsonb_build_object(
            'data_space', data_space,
            'entity_id', inserted_entity_id,
            'label', key_column_label,
            'developer_name', key_column_dev_name,
            'data_type', 'key',
            'pg_data_type', 'serial',
            'created_by', user_id,
            'last_modified_by', user_id
        )::jsonb,
        jsonb_build_object(
            'data_space', data_space,
            'entity_id', inserted_entity_id,
            'label', id_column_label,
            'developer_name', id_column_dev_name,
            'data_type', 'id',
            'pg_data_type', 'varchar(22)',
            'created_by', user_id,
            'last_modified_by', user_id
        )::jsonb,
        jsonb_build_object(
            'data_space', data_space,
            'entity_id', inserted_entity_id,
            'label', 'Name',
            'developer_name', 'name',
            'data_type', 'text',
            'length', '80',
            'pg_data_type', 'varchar(80)',
            'created_by', user_id,
            'last_modified_by', user_id
        )::jsonb,
        jsonb_build_object(
            'data_space', data_space,
            'entity_id', inserted_entity_id,
            'label', 'Created Date',
            'developer_name', 'created_date',
            'data_type', 'date_time',
            'pg_data_type', 'timestamptz',
            'created_by', user_id,
            'last_modified_by', user_id,
            'is_standard',true
        )::jsonb,
        jsonb_build_object(
            'data_space', data_space,
            'entity_id', inserted_entity_id,
            'label', 'Last Modified Date',
            'developer_name', 'last_modified_date',
            'data_type', 'date_time',
            'pg_data_type', 'timestamptz',
            'created_by', user_id,
            'last_modified_by', user_id,
            'is_standard',true
        )::jsonb,
        jsonb_build_object(
            'data_space', data_space,
            'entity_id', inserted_entity_id,
            'label', 'Created By',
            'developer_name', 'created_by',
            'data_type', 'lookup',
            'pg_data_type', 'varchar(22)',
            'created_by', user_id,
            'is_standard',true,
            'last_modified_by', user_id,
			'parent_entity_id',parent_entity_id
        )::jsonb,
        jsonb_build_object(
            'data_space', data_space,
            'entity_id', inserted_entity_id,
            'label', 'Last Modified By',
            'developer_name', 'last_modified_by',
            'data_type', 'lookup',
            'pg_data_type', 'varchar(22)',
            'is_standard',true,
            'created_by', user_id,
            'last_modified_by', user_id,
			'parent_entity_id',parent_entity_id
        )::jsonb,
		jsonb_build_object(
            'data_space', data_space,
            'entity_id', inserted_entity_id,
            'label', 'Owner Id',
            'developer_name', 'owner_id',
            'data_type', 'lookup',
            'pg_data_type', 'varchar(22)',
            'is_standard',true,
            'created_by', user_id,
            'last_modified_by', user_id,
			'parent_entity_id',parent_entity_id
        )::jsonb
    )::jsonb;
	
	--Adding top level data in the column_json  
	column_json := jsonb_build_object(
	    'data_space', data_space,
	    'meta_table', meta_table,
	    'active_session', jsonb_build_object('session_token', session_token),
	    'data', column_json
	)::jsonb;

	RAISE NOTICE 'Default column_json: % ', column_json;

	-- Call create column Function
	PERFORM production.create_new_column_function(column_json::jsonb);	
	return column_json;
END;
$function$
;
