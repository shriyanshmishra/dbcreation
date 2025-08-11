-- DROP FUNCTION production.fetch_tab_list_function();

CREATE OR REPLACE FUNCTION production.fetch_tab_list_function()
 RETURNS json
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN (
    SELECT json_agg(row_to_json(t))
    FROM (
      SELECT 
		tab_id,
        label,
        description,
        is_restricted,
		tab_style
      FROM production.tab_meta
      ORDER BY label
    ) t
  );
END;
$function$
;
