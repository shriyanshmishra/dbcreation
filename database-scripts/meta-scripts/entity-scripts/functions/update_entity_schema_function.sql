CREATE OR REPLACE FUNCTION production.update_entity_schema_function(json_input jsonb)
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
    item jsonb;
    data_space text := json_input->>'data_space';
    old_dev_name text;
    new_dev_name text;
    old_label text;
    new_label text;
    old_plural_label text;
    new_plural_label text;
BEGIN
    FOR item IN SELECT * FROM jsonb_array_elements(json_input->'data')
    LOOP
		SELECT label, plural_label, developer_name INTO
		old_label, old_plural_label, old_dev_name
		FROM production.entity_meta
		WHERE entity_id = item->>'entity_id';
		
        new_dev_name := item->>'developer_name';
        new_label := item->>'label';
        new_plural_label := item->>'plural_label';

        -- Check if developer_name has changed
        IF old_dev_name IS DISTINCT FROM new_dev_name THEN
             
			RAISE NOTICE 'Developer_name is Changed : % , % ',old_dev_name, new_dev_name;
            -- Update entity data table (rename columns, primary key, constraints)
            PERFORM production.update_entity_data_table_function(data_space, old_dev_name, new_dev_name);

            -- Update entity share table (rename columns, primary key, constraints)
            PERFORM production.update_entity_share_table_function(data_space, old_dev_name, new_dev_name);

			--Update entity data table and share table views
			PERFORM production.update_entity_data_table_and_share_table_views_function(item->>'entity_id'::text, old_dev_name, old_label, new_dev_name, new_label);

			-- Update entity_meta table
            PERFORM production.update_into_entity_meta_table_function(item->>'entity_id'::text, new_label, new_plural_label, new_dev_name);
        -- Check if only label or plural_label has changed
        ELSIF old_label IS DISTINCT FROM new_label OR old_plural_label IS DISTINCT FROM new_plural_label THEN
            
			RAISE NOTICE 'plural_label old->> %, new->> % & label old-> %, new-> % ',old_plural_label, new_plural_label, old_label, new_label;			
	
			-- Only update the labels in entity_meta table
			PERFORM production.update_into_entity_meta_table_function(item->>'entity_id'::text, new_label, new_plural_label, new_dev_name);
        END IF;
    END LOOP;

    RETURN 'Entity schema update completed successfully.';
END;
$$;