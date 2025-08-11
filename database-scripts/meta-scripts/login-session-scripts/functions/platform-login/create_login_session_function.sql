-- DROP FUNCTION IF EXISTS production.create_login_session_function(payload jsonb);
CREATE OR REPLACE FUNCTION production.create_login_session_function(payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
   item                jsonb;
   full_table_name     text;
   inserted_session_id text;
   data_space          text;
   meta_table          text;
   user_id             text;
   dup_count           int;
   user_lookup         jsonb;
BEGIN
   -------------------------------------------------------------
   -- 1) Top‐level payload validation
   -------------------------------------------------------------
   IF NOT (payload ? 'data_space' AND payload ? 'meta_table' AND payload ? 'data') THEN
      RETURN jsonb_build_object('error_code','1001','message','Missing required top-level keys');

   END IF;
   IF jsonb_typeof(payload->'data') <> 'array' THEN
      RETURN jsonb_build_object('error_code','1002','message','"data" is not in array format');
   END IF;

   data_space := payload->>'data_space';
   meta_table := payload->>'meta_table';

   -------------------------------------------------------------
   -- 2) Schema & meta_table existence
   -------------------------------------------------------------
   IF NOT EXISTS (
      SELECT 1 FROM information_schema.schemata WHERE schema_name = data_space
   ) THEN
      RETURN jsonb_build_object('error_code','1005','message','Schema not found');
   END IF;
   IF meta_table <> 'login_session_meta' THEN
      RETURN jsonb_build_object('error_code','1006','message','Entity schema not found');
   END IF;

   full_table_name := format('%I.%I', data_space, meta_table);

   -------------------------------------------------------------
   -- 3) Per-item validation & insert
   -------------------------------------------------------------
   FOR item IN SELECT * FROM jsonb_array_elements(payload->'data')
   LOOP
       -- 3a) Required fields
       IF NOT (
           item ? 'user_id' AND
           item ? 'login_provider' AND
           item ? 'session_token' AND
           item ? 'ip_address' AND
           item ? 'user_agent' AND
           item ? 'session_start' AND
           item ? 'is_active'
       ) THEN
           RETURN jsonb_build_object('error_code','1007','message','Missing one of the required session fields');
       END IF;

       user_id := item->>'user_id';

       -- 3b) Validate user via helper
       user_lookup := production.get_user_details(user_id);
       IF user_lookup->0 ? 'error_code' THEN
         -- propagate the exact error from get_user_details
         RETURN jsonb_build_object(
           'error_code', user_lookup->0->>'error_code',
           'message',    user_lookup->0->>'Message'
         );
       END IF;

       -- 3c) Prevent duplicate session_token
       EXECUTE format(
           'SELECT COUNT(*) FROM %I.%I WHERE session_token = $1', 
            data_space, meta_table
       )
       INTO dup_count
       USING item->>'session_token';

       IF dup_count > 0 THEN
          RETURN jsonb_build_object('error_code','1007','message','Duplicate session_token');
       END IF;

       -- 3d) Safe INSERT
       EXECUTE format('
           INSERT INTO %s (
               login_provider,
               session_token,
               ip_address,
               user_agent,
               session_start,
               is_active,
               user_id
           )
           VALUES (
               $1, $2, $3, $4, $5::timestamptz, $6::boolean, $7
           )
           RETURNING login_session_id
       ', full_table_name)
       INTO inserted_session_id
       USING
           item->>'login_provider',
           item->>'session_token',
           item->>'ip_address',
           item->>'user_agent',
           item->>'session_start',
           item->>'is_active',
           user_id;

       -- on success, break out (we assume one session per call)
       EXIT;
   END LOOP;

   -------------------------------------------------------------
   -- 4) Return success
   -------------------------------------------------------------
   RETURN jsonb_build_object(
     'session_id', inserted_session_id
   );
END;
$function$
;
