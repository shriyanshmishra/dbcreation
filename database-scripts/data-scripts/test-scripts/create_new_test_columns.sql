DO $$
DECLARE
    inserted_entity_id varchar(22);
	child_inserted_entity_id varchar(22);
    column_json jsonb;
BEGIN
    -- Fetch inserted_entity_id for 'account'
    SELECT entity_id INTO inserted_entity_id 
    FROM production.entity_meta 
    WHERE developer_name = 'account';

    -- Fetch inserted_entity_id for 'contact' (used as parent_inserted_entity_id)
    SELECT entity_id INTO child_inserted_entity_id 
    FROM production.entity_meta 
    WHERE developer_name = 'contact';

    RAISE NOTICE 'entity_id % , child_id %',inserted_entity_id,child_inserted_entity_id;
	column_json := jsonb_build_array(
        jsonb_build_object(  
            'data_space','production',
            'entity_id', child_inserted_entity_id,
            'developer_name', 'custom_lookup_column',
            'label', 'Custom Lookup Column',
            'data_type', 'lookup',
            'parent_entity_id', inserted_entity_id
        )::jsonb,
        jsonb_build_object(
            'data_space','production',
            'entity_id', child_inserted_entity_id,
            'developer_name', 'custom_master_column',
            'label', 'Custom Master Column',
            'data_type', 'master',
            'parent_entity_id', inserted_entity_id
        )::jsonb,
        jsonb_build_object(
            'data_space','production',
            'entity_id', inserted_entity_id,
            'developer_name', 'checkbox_column',
            'label', 'Checkbox Column',
            'data_type', 'checkbox',
            'boolean_value',true,
            'required', false
        )::jsonb,
        jsonb_build_object(
            'data_space','production',
            'entity_id', inserted_entity_id,
            'developer_name', 'time_column',
            'label', 'Time Column',
            'data_type', 'time',
            'required', true
        )::jsonb,
        jsonb_build_object(
            'data_space','production',
            'entity_id', inserted_entity_id,
            'developer_name', 'date_column',
            'label', 'Date Column',
            'data_type', 'date',
            'required', true
        )::jsonb,
        jsonb_build_object(
            'data_space','production',
            'entity_id', inserted_entity_id,
            'developer_name', 'date_time_column',
            'label', 'Date Time Column',
            'data_type', 'date_time',
            'required', false
        )::jsonb,
        jsonb_build_object(
            'data_space','production',
            'entity_id', inserted_entity_id,
            'developer_name', 'email_column',
            'label', 'Email Column',
            'data_type', 'email',
            'required', true,
            'unique', true
        )::jsonb,
        jsonb_build_object(
            'data_space','production',
            'entity_id', inserted_entity_id,
            'developer_name', 'phone_column',
            'label', 'Phone Column',
            'data_type', 'phone',
            'required', false
        )::jsonb,
        jsonb_build_object(
            'data_space', 'production',
            'entity_id', inserted_entity_id,
            'developer_name', 'picklist_column',
            'label', 'Picklist Column',
            'data_type', 'picklist',
            'picklist_values', jsonb_build_array(
                jsonb_build_object('value', 'New', 'value_developer_name', 'new', 'default', true, 'status', 'Active'),
                jsonb_build_object('value', 'In Progress', 'value_developer_name', 'in_progress', 'default', false, 'status', 'Active'),
                jsonb_build_object('value', 'Completed', 'value_developer_name', 'completed', 'default', false, 'status', 'Active'),
                jsonb_build_object('value', 'On Hold', 'value_developer_name', 'on_hold', 'default', false, 'status', 'Active')
            )
        )::jsonb,
        jsonb_build_object(
            'data_space', 'production',
            'entity_id', inserted_entity_id,
            'developer_name', 'multi_picklist_column',
            'label', 'Multi Picklist Column',
            'data_type', 'multi_picklist',
            'picklist_values', jsonb_build_array(
                jsonb_build_object('value', 'New', 'value_developer_name', 'new', 'default', true, 'status', 'Active'),
                jsonb_build_object('value', 'In Progress', 'value_developer_name', 'in_progress', 'default', false, 'status', 'Active'),
                jsonb_build_object('value', 'Completed', 'value_developer_name', 'completed', 'default', false, 'status', 'Active'),
                jsonb_build_object('value', 'On Hold', 'value_developer_name', 'on_hold', 'default', false, 'status', 'Active')
            )
        )::jsonb,
        jsonb_build_object(
            'data_space','production',
            'entity_id', inserted_entity_id,
            'developer_name', 'url_column',
            'label', 'Url Column',
            'data_type', 'url',
            'required', false
        )::jsonb,
        jsonb_build_object(
            'data_space','production',
            'entity_id', inserted_entity_id,
            'developer_name', 'currency_column',
            'label', 'Currency Column',
            'data_type', 'currency',
            'integer', 15,
            'decimal', 3,
            'required', true
        )::jsonb,
        jsonb_build_object(
            'data_space','production',
            'entity_id', inserted_entity_id,
            'developer_name', 'number_column',
            'label', 'Number Column',
            'data_type', 'number',
            'integer', 18,
            'decimal', 0,
            'required', true
        )::jsonb,
        jsonb_build_object(
            'data_space','production',
            'entity_id', inserted_entity_id,
            'developer_name', 'percent_column',
            'label', 'Percent Column',
            'data_type', 'percent',
            'integer', 16,
            'decimal', 2,
            'required', true
        )::jsonb,
        jsonb_build_object(
            'data_space','production',
            'entity_id', inserted_entity_id,
            'developer_name', 'geolocation_column',
            'label', 'Geolocation Column',
            'data_type', 'geolocation',
            'required', false
        )::jsonb,
        jsonb_build_object(
            'data_space','production',
            'entity_id', inserted_entity_id,
            'developer_name', 'text_column',
            'label', 'Text Column',
            'data_type', 'text',
            'length', 255,
            'required', true
        )::jsonb,
        jsonb_build_object(
            'data_space','production',
            'entity_id', inserted_entity_id,
            'developer_name', 'text_area_column',
            'label', 'Text Area Column',
            'data_type', 'text_area',
            'required', false
        )::jsonb,
        jsonb_build_object(
            'data_space','production',
            'entity_id', inserted_entity_id,
            'developer_name', 'text_area_long_column',
            'label', 'Text Area Long Column',
            'data_type', 'text_area_long',
            'length',4055,
            'required', false
        )::jsonb,
        jsonb_build_object(
            'data_space','production',
            'entity_id', inserted_entity_id,
            'developer_name', 'text_area_rich_column',
            'label', 'Text Area Rich Column',
            'data_type', 'text_area_rich',
            'length',3021,
            'required', false
        )::jsonb,
        jsonb_build_object(
            'data_space','production',
            'entity_id', inserted_entity_id,
            'developer_name', 'auto_number_column',
            'label', 'Auto Number Column',
            'data_type', 'auto_number',
            'auto_number_prefix', 'AAA',
            'starting_number', 18
        )::jsonb,
        jsonb_build_object(
            'data_space','production',
            'entity_id', inserted_entity_id,
            'developer_name', 'roll_up_summary_column',
            'label', 'Roll Up Summary Column',
            'data_type', 'rollup'
        )::jsonb
    )::jsonb;
    
    --Adding top level data in the column_json  
	column_json := jsonb_build_object(
	    'data_space', 'production',
	    'meta_table', 'column_meta',
	    'active_session', jsonb_build_object('session_token', 'Default-session-for-testing'),
	    'data', column_json
	)::jsonb;

    PERFORM production.create_new_column_function(column_json::jsonb);
END $$;
