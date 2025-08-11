CREATE OR REPLACE FUNCTION production.get_entity_details_function(p_id text)
RETURNS JSON AS $$
BEGIN
    RETURN (
        SELECT row_to_json(t)
        FROM (
            SELECT 
                entity_id as id,
                label,
                plural_label,
                developer_name,
                prefix,
                allow_reports,
                allow_activities,
                track_field_history,
                allow_sharing,
                in_development,
                deployed
            FROM production.entity_meta
            WHERE entity_id = p_id  and entity_type = 'data'
        ) t
    );
END;
$$ LANGUAGE plpgsql;