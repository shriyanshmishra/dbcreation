-- DROP FUNCTION production.validate_formula(jsonb);
CREATE OR REPLACE FUNCTION production.validate_formula(input_json jsonb)
RETURNS jsonb
LANGUAGE plpgsql
AS $function$
DECLARE
 formula_expr     TEXT;
 p_entity_id      TEXT;
 working_expr     TEXT;
 token_expr       TEXT;
 field_names      TEXT[];
 used_fields      TEXT[];
 tok              TEXT;
 rec              RECORD;
 ignored_keywords TEXT[] := ARRAY[
   'if','case','when','then','else','end',
   'extract','year','month','day',
   'length','upper','lower','trim','btrim',
   'round','concat','current_timestamp','current_date',
   'is','null','and','or','not',
   'value','text','now','today','isblank'
 ];
BEGIN
 -- Extract values from JSON input
 formula_expr := input_json->>'formula_expression';
 p_entity_id  := input_json->>'EntityId';
 /* ─────────────── 1) Empty formula ─────────────── */
 IF formula_expr IS NULL OR trim(formula_expr) = '' THEN
   RAISE NOTICE '[1407] Blank formula received';
   RETURN production.get_response_message(
     jsonb_build_object('data',
       jsonb_build_array(jsonb_build_object('error_code','1407'))
     )
   );
 END IF;
 /* ─────────────── 2) Allowed fields list ───────── */
 SELECT array_agg(developer_name)
   INTO field_names
   FROM production.column_meta
  WHERE entity_id = p_entity_id;
 IF field_names IS NULL THEN
   RAISE NOTICE '[1408] No columns found for entity_id %', p_entity_id;
   RETURN production.get_response_message(
     jsonb_build_object('data',
       jsonb_build_array(jsonb_build_object('error_code','1408'))
     )
   );
 END IF;
 /* ─────────────── 3-5) Tokenise & field check ──── */
 token_expr := regexp_replace(formula_expr, '''[^'']*''', '', 'g');
 token_expr := regexp_replace(token_expr, '"[^"]*"',  '', 'g');
 FOR tok IN
     SELECT DISTINCT word
       FROM regexp_split_to_table(token_expr, '[^A-Za-z0-9_]+') AS word
      WHERE word <> ''
        AND NOT word ~ '^[0-9]+(\.[0-9]+)?$'
        AND lower(word) NOT IN (SELECT unnest(ignored_keywords))
 LOOP
   used_fields := array_append(used_fields, tok);
 END LOOP;
 FOREACH tok IN ARRAY used_fields LOOP
   IF NOT tok = ANY(field_names) THEN
     RAISE NOTICE '[1409] Unknown field % in formula', tok;
     RETURN production.get_response_message(
       jsonb_build_object('data',
         jsonb_build_array(jsonb_build_object('error_code','1409'))
       )
     );
   END IF;
 END LOOP;
 /* ─────────────── 6) SF → PG translation ───────── */
 working_expr := replace(formula_expr, '''', '''''');
 working_expr := regexp_replace(working_expr, '"([^"]*)"', '''\1''', 'g');
 working_expr := regexp_replace(
   working_expr,
   'IF\(\s*([^,]+?)\s*,\s*([^,]+?)\s*,\s*([^)]+?)\s*\)',
   'CASE WHEN \1 THEN \2 ELSE \3 END','gi');
 working_expr := regexp_replace(working_expr, '\yLEN\(([^)]+?)\)',    'LENGTH(\1)','gi');
 working_expr := regexp_replace(working_expr, '\yTEXT\(([^)]+?)\)',   '(\1)::text','gi');
 working_expr := regexp_replace(working_expr, '\yVALUE\(([^)]+?)\)',  '(\1)::numeric','gi');
 working_expr := regexp_replace(working_expr, '\yUPPER\(([^)]+?)\)',  'UPPER(\1)','gi');
 working_expr := regexp_replace(working_expr, '\yLOWER\(([^)]+?)\)',  'LOWER(\1)','gi');
 working_expr := regexp_replace(working_expr, '\yTRIM\(([^)]+?)\)',   'BTRIM(\1)','gi');
 working_expr := regexp_replace(working_expr, '\yCONCAT\(([^)]+?)\)', 'CONCAT(\1)','gi');
 working_expr := regexp_replace(working_expr, '\yROUND\(([^,]+?),\s*([^)]+?)\)',
                                                      'ROUND(\1, \2)','gi');
 working_expr := regexp_replace(working_expr, '\yNOW\(\)',   'CURRENT_TIMESTAMP','gi');
 working_expr := regexp_replace(working_expr, '\yTODAY\(\)', 'CURRENT_DATE','gi');
 working_expr := regexp_replace(working_expr, '\yISBLANK\(([^)]+?)\)', '\1 IS NULL','gi');
 /* ─────────────── 7) Substitute NULL::type ─────── */
 FOR rec IN
     SELECT developer_name, pg_data_type
       FROM production.column_meta
      WHERE entity_id = p_entity_id
 LOOP
   working_expr := regexp_replace(
     working_expr,
     E'\\y' || rec.developer_name || E'\\y',
     'NULL::' || rec.pg_data_type,
     'gi'
   );
 END LOOP;
 /* ─────────────── 8) Syntax & semantic check ───── */
 BEGIN
   EXECUTE format('SELECT %s', working_expr);
 EXCEPTION
   WHEN SQLSTATE '42804' OR SQLSTATE '42883' THEN
     RAISE NOTICE '[1410] Datatype mismatch: %', SQLERRM;
     RETURN production.get_response_message(
       jsonb_build_object('data',
         jsonb_build_array(
           jsonb_build_object('error_code','1410',
                              'error_message','Datatype mismatch or unsupported operator/function')
         )
       )
     );
   WHEN SQLSTATE '42601' THEN
     RAISE NOTICE '[1411] Syntax error: %', SQLERRM;
     RETURN production.get_response_message(
       jsonb_build_object('data',
         jsonb_build_array(
           jsonb_build_object('error_code','1411',
                              'error_message','Invalid formula syntax or operator')
         )
       )
     );
   WHEN OTHERS THEN
     RAISE NOTICE '[1405] Unhandled validation error: %', SQLERRM;
     RETURN production.get_response_message(
       jsonb_build_object('data',
         jsonb_build_array(jsonb_build_object('error_code','1405'))
       )
     );
 END;
 /* ─────────────── 9) Success ───────────────────── */
 RAISE NOTICE '[2004] Formula validated successfully. SQL: %', working_expr;
 RETURN jsonb_build_object(
   'response', jsonb_build_array(
     jsonb_build_object(
       'success_code',   '2004',
       'translated_sql', working_expr
     )
   )
 );
END;
$function$
;

