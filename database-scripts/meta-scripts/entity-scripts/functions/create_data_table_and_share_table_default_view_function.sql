-- DROP FUNCTION production.create_data_table_and_share_table_default_view_function(text, text, text, text);

CREATE OR REPLACE FUNCTION production.create_data_table_and_share_table_default_view_function(entity_plural_label text, entity_developer_name text, data_space text, session_token text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    view_json jsonb;
    dev varchar(255);
BEGIN
    dev= (production.remove_special_characters(entity_developer_name)); 
    RAISE NOTICE 'entity_plural_name: %', entity_plural_label;

	-- Dynamically build the view JSON array (with explicit JSONB casting)
    view_json := jsonb_build_array(
        jsonb_build_object(
            'view_name', 'All ' || entity_plural_label,
            'view_developer_name', 'all_' || dev || 's',
            'columns', jsonb_build_array('name'),  -- Hardcoded columns for 'All'
            'filter_by_owner', 'all',
            'filters', jsonb_build_array(
                jsonb_build_object(
                    'column_developer_name', '',
                    'operator', '',
                    'value', ''
                )
            )  
        ),
        jsonb_build_object(
            'view_name', 'My ' || entity_plural_label,
            'view_developer_name', 'my_' || dev || 's',
            'columns', jsonb_build_array('name'),  -- Hardcoded columns for 'My'
            'filter_by_owner', 'my',
            'filters', jsonb_build_array(
                jsonb_build_object(
                    'column_developer_name', '',
                    'operator', '',
                    'value', ''
                )
            )  
        ),
        jsonb_build_object(
            'view_name', 'Today ' || entity_plural_label,
            'view_developer_name', 'today_' || dev || 's',
            'columns', jsonb_build_array('name','created_date'),  -- Hardcoded columns for 'Today'
            'filter_by_owner', '',
            'filters', jsonb_build_array(
                jsonb_build_object(
		            'column_developer_name', 'created_date',
		            'operator', 'greater or equal',
		            'value', 'Today()'
                )
            )  
        )
    );

    -- Add top-level data in the view_json
    view_json := jsonb_build_object(
        'data_space', data_space,
        'entity', dev,
        'active_session', jsonb_build_object('session_token', session_token),
        'standard', true,
        'data', view_json
    );

    RAISE NOTICE 'Generated view_json: %', view_json;

    -- Call the create column function (as you specified in your code)
    PERFORM production.create_data_table_and_share_table_views_function(view_json::jsonb);

    -- Return the generated JSON
    RETURN view_json;
END;
$function$
;
