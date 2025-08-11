-- DROP FUNCTION production.fetch_user_details_function(jsonb);
CREATE OR REPLACE FUNCTION production.fetch_user_details_function(input_json jsonb)
RETURNS jsonb
LANGUAGE plpgsql
AS $function$
DECLARE
   v_user_id    text := input_json ->> 'user_id';
   v_username   text := input_json ->> 'username';
   result_json  jsonb;
BEGIN
   IF v_user_id IS NULL AND v_username IS NULL THEN
       RAISE EXCEPTION
         'Input JSON must contain either "user_id" or "username".  Got: %',
         input_json::text;
   END IF;
   SELECT COALESCE(
           
              /* full row as JSON, minus sensitive or raw fields            */
              to_jsonb(u)
              - 'created_date'
              - 'last_modified_date'
			   - 'otp_expires_at'
			   - 'otp_hash'
			   - 'otp_used'
			   - 'user_key'
			   - 'default_role'
              - 'last_password_change'
              || jsonb_build_object(
                    'created_date',
                    to_char(u.created_date,       'YYYY-MM-DD HH12:MI:SS AM'),
                    'last_modified_date',
                    to_char(u.last_modified_date, 'YYYY-MM-DD HH12:MI:SS AM')
                
            ),
            '{}'::jsonb
          )
     INTO result_json
     FROM production."user"  AS u
    WHERE (v_user_id  IS NOT NULL AND u.user_id  = v_user_id)
       OR (v_username IS NOT NULL AND u.username = v_username);
   RETURN result_json;
END;
$function$
;