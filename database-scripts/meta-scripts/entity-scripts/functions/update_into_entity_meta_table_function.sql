CREATE OR REPLACE FUNCTION production.update_into_entity_meta_table_function(
    target_entity_id text,
    new_label text,
    new_plural_label text,
    new_dev_name text
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    old_dev_name text;
    share_dev_name text;
    share_entity_id text;
BEGIN
    -- Step 1: Get the old developer name for the data entity
    SELECT developer_name INTO old_dev_name
    FROM production.entity_meta
    WHERE entity_id = target_entity_id;

    -- Step 2: Update the data entity row if values differ
    UPDATE production.entity_meta
    SET 
        label = CASE WHEN label IS DISTINCT FROM new_label THEN new_label ELSE label END,
        plural_label = CASE WHEN plural_label IS DISTINCT FROM new_plural_label THEN new_plural_label ELSE plural_label END,
        developer_name = CASE WHEN developer_name IS DISTINCT FROM new_dev_name THEN new_dev_name ELSE developer_name END
    WHERE entity_id = target_entity_id;

    -- Step 3: Build share developer name
    share_dev_name := old_dev_name || '_share';

    -- Step 4: Get share entity ID if exists
    SELECT entity_id INTO share_entity_id
    FROM production.entity_meta
    WHERE developer_name = share_dev_name;

    -- Step 5: If share entity exists, update it accordingly
    IF share_entity_id IS NOT NULL THEN
        UPDATE production.entity_meta
        SET 
            label = CASE WHEN label IS DISTINCT FROM (new_label || ' Share') THEN (new_label || ' Share') ELSE label END,
            plural_label = CASE WHEN plural_label IS DISTINCT FROM (new_plural_label || ' Shares') THEN (new_plural_label || ' Shares') ELSE plural_label END,
            developer_name = CASE WHEN developer_name IS DISTINCT FROM (new_dev_name || '_share') THEN (new_dev_name || '_share') ELSE developer_name END
        WHERE entity_id = share_entity_id;
    END IF;
END;
$$;