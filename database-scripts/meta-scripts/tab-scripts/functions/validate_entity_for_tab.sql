-- DROP FUNCTION production.validate_entity_for_tab(jsonb);

CREATE OR REPLACE FUNCTION production.validate_entity_for_tab(input_json jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_meta_table TEXT;
  v_entity_id  TEXT;
BEGIN
  -- 1) Validate meta_table
  v_meta_table := input_json ->> 'meta_table';
  IF v_meta_table IS NULL OR v_meta_table <> 'tab_meta' THEN
    RETURN production.get_response_message(
      '{"data":[{"error_code":"1706"}]}'::jsonb
    );
  END IF;

  -- 2) Validate structure and extract entity_id
  IF jsonb_typeof(input_json -> 'data') IS DISTINCT FROM 'array' THEN
    RETURN production.get_response_message(
      '{"data":[{"error_code":"1700"}]}'::jsonb
    );
  END IF;

  v_entity_id := input_json -> 'data' -> 0 ->> 'entity_id';

  IF v_entity_id IS NULL OR trim(v_entity_id) = '' THEN
    RETURN production.get_response_message(
      '{"data":[{"error_code":"1700"}]}'::jsonb
    );
  END IF;

  -- 3) Check existence of entity_id
  IF EXISTS (
    SELECT 1
      FROM production.entity_meta
     WHERE entity_id = v_entity_id
  ) THEN
    RETURN production.get_response_message(
      '{"data":[{"success_code":"2012"}]}'::jsonb
    );
  ELSE
    RETURN production.get_response_message(
      '{"data":[{"error_code":"1703"}]}'::jsonb
    );
  END IF;
END;
$function$
;
