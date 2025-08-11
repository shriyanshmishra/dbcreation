-- DROP FUNCTION production.fetch_tab_details_function(text);

CREATE OR REPLACE FUNCTION production.fetch_tab_details_function(p_tab_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  details jsonb;
BEGIN
  SELECT coalesce(
    jsonb_agg(
      to_jsonb(t)
      -- remove raw fields
      - 'created_date'
      - 'last_modified_date'
      - 'created_by'
      - 'last_modified_by'
	  -  'tab_style'
      -- merge in formatted fields
      || jsonb_build_object(
           'Created By',     (production.get_user_details(t.created_by)      -> 0 ->> 'Name')
                              || ', ' || to_char(t.created_date,       'DD/MM/YYYY, HH12:MI AM'),
           'Modified By',    (production.get_user_details(t.last_modified_by)-> 0 ->> 'Name')
                              || ', ' || to_char(t.last_modified_date, 'DD/MM/YYYY, HH12:MI AM'),
           'Tab Style',      encode(t.tab_style, 'base64')
         )
    ),
    '[]'::jsonb
  )
  INTO details
  FROM (
    SELECT
      tm.label             AS "Tab Label",
      em.label             AS "Entity",
      tm.description       AS "Description",
      tm.tab_style,                             
      tm.created_date,
      tm.last_modified_date,
      tm.created_by,
      tm.last_modified_by
    FROM production.tab_meta tm
    LEFT JOIN production.entity_meta em 
      ON em.entity_id = tm.entity_id
    WHERE tm.tab_id = p_tab_id
  ) AS t;

  RETURN details;
END;
$function$
;
