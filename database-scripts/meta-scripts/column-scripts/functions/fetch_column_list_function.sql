CREATE OR REPLACE FUNCTION production.fetch_column_list_function(col_id TEXT)
RETURNS JSON AS $$
BEGIN
    RETURN (
        SELECT json_agg(row_to_json(t))
        FROM (
            SELECT 
                column_id AS col_id,
                label AS "Field_Label",
                developer_name AS "Field_Name",
                data_type AS "Data_Type",
                "length",
                integer,
                decimal,
                latitude,
                longitude,
                boolean_value,
                required,
                "unique",
                picklist,
                multi_picklist,
                pg_data_type,
                if_delete_clean_values,
                do_not_allow_deletion,
                is_deletable,
                created_date,
                last_modified_date,
                created_by,
                last_modified_by
            FROM production.column_meta 
            WHERE entity_id = col_id
        ) t
    );
END;
$$ LANGUAGE plpgsql;