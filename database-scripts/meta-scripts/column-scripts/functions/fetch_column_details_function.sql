-- DROP FUNCTION production.fetch_column_details_function(text);

CREATE OR REPLACE FUNCTION production.fetch_column_details_function(col_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  result_json JSONB;
BEGIN
  SELECT coalesce(
    jsonb_agg(
      -- start with the row as JSONB
      to_jsonb(cm)
      -- remove the raw timestamp fields
      - 'created_date'
      - 'last_modified_date'
      -- merge in your formatted dates + username
      || jsonb_build_object(
           'created_date',       to_char(cm.created_date,      'YYYY-MM-DD HH12:MI:SS AM'),
           'last_modified_date', to_char(cm.last_modified_date,'YYYY-MM-DD HH12:MI:SS AM'),
           'username',
             ( production.get_user_details(cm.created_by) -> 0 ->> 'Name' )
         )
    ),
    '[]'::jsonb
  )
  INTO result_json
  FROM production.column_meta cm
  WHERE cm.column_id = col_id;


  RETURN result_json;
END;
$function$
;