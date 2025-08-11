-- DROP FUNCTION production.create_user_function(jsonb);

CREATE OR REPLACE FUNCTION production.create_user_function(json_input jsonb)
RETURNS jsonb
LANGUAGE plpgsql
AS $function$
DECLARE
   item             jsonb;
   current_user_id  varchar(22);
   new_user_id      varchar(22);
   inserted_email   text;
   required_keys    text[] := ARRAY['data_space', 'active_session', 'data'];
   missing_top_keys text[];
BEGIN
   -- 1. Top-level key validation (1001)
   missing_top_keys := ARRAY(
       SELECT k FROM unnest(required_keys) AS k
       WHERE NOT json_input ? k
   );

   IF array_length(missing_top_keys, 1) IS NOT NULL THEN
       RETURN production.get_response_message(jsonb_build_object(
           'data', jsonb_build_array(jsonb_build_object('error_code', '1001')),
           'active_session', json_input->'active_session'
       ));
   END IF;

   -- 2. "data" must be array (1002)
   IF jsonb_typeof(json_input->'data') <> 'array' THEN
       RETURN production.get_response_message(jsonb_build_object(
           'data', jsonb_build_array(jsonb_build_object('error_code', '1002')),
           'active_session', json_input->'active_session'
       ));
   END IF;

   -- 3. Validate session token and fetch user_id (1003)
   SELECT user_id INTO current_user_id
   FROM production.login_session_meta
   WHERE session_token = json_input->'active_session'->>'session_token';

   IF current_user_id IS NULL THEN
       RETURN production.get_response_message(jsonb_build_object(
           'data', jsonb_build_array(jsonb_build_object('error_code', '1003')),
           'active_session', json_input->'active_session'
       ));
   END IF;

   -- 4. Loop through array elements
   FOR item IN SELECT * FROM jsonb_array_elements(json_input->'data') LOOP

       -- 4a. Field validation with specific error codes
       IF coalesce(item->>'last_name', '') = '' THEN
           RETURN production.get_response_message(jsonb_build_object(
               'data', jsonb_build_array(jsonb_build_object('error_code', '1501')), -- LastName required
               'active_session', json_input->'active_session'
           ));
       ELSIF coalesce(item->>'alias', '') = '' THEN
           RETURN production.get_response_message(jsonb_build_object(
               'data', jsonb_build_array(jsonb_build_object('error_code', '1502')), -- Alias is required
               'active_session', json_input->'active_session'
           ));
       ELSIF coalesce(item->>'email', '') = '' THEN
           RETURN production.get_response_message(jsonb_build_object(
               'data', jsonb_build_array(jsonb_build_object('error_code', '1504')), -- Email is required
               'active_session', json_input->'active_session'
           ));
       ELSIF coalesce(item->>'username', '') = '' THEN
           RETURN production.get_response_message(jsonb_build_object(
               'data', jsonb_build_array(jsonb_build_object('error_code', '1506')), -- Username required
               'active_session', json_input->'active_session'
           ));
       END IF;

       -- 4b. Duplicate checks
       IF EXISTS (
           SELECT 1 FROM production."user"
           WHERE lower(username) = lower(item->>'username')
       ) THEN
           RETURN production.get_response_message(jsonb_build_object(
               'data', jsonb_build_array(jsonb_build_object('error_code', '1505')), -- Username already exists
               'active_session', json_input->'active_session'
           ));
       ELSIF EXISTS (
           SELECT 1 FROM production."user"
           WHERE lower(email) = lower(item->>'email')
       ) THEN
           RETURN production.get_response_message(jsonb_build_object(
               'data', jsonb_build_array(jsonb_build_object('error_code', '1503')), -- Email already exists
               'active_session', json_input->'active_session'
           ));
       END IF;

       -- 4c. Insert user
       BEGIN
           INSERT INTO production."user" (
               first_name, last_name, username, alias, email, active,
               postal_code, street, state, nickname, division, department, company,
               phone, mobile, time_zone, language,
               country, city, locale, profile,
               created_by, last_modified_by,
               created_date, last_modified_date
           )
           VALUES (
               item->>'first_name',
               item->>'last_name',
               item->>'username',
               item->>'alias',
               lower(item->>'email'),
               COALESCE((item->>'active')::boolean, false),
               item->>'postal_code',
               item->>'street',
               item->>'state',
               item->>'nickname',
               item->>'division',
               item->>'department',
               item->>'company',
               item->>'phone',
               item->>'mobile',
               item->>'time_zone',
               item->>'language',
               item->>'country',
               item->>'city',
               item->>'locale',
               item->>'profile',
               current_user_id,
               current_user_id,
               CURRENT_TIMESTAMP,
               CURRENT_TIMESTAMP
           )
           RETURNING user_id INTO new_user_id;

           inserted_email := lower(item->>'email');

       EXCEPTION WHEN OTHERS THEN
           RETURN production.get_response_message(jsonb_build_object(
               'data', jsonb_build_array(jsonb_build_object('error_code', '1507')), -- Unexpected error during insert
               'active_session', json_input->'active_session'
           ));
       END;
   END LOOP;

   -- 5. Success response (2000)
   RETURN production.get_response_message(jsonb_build_object(
       'data', jsonb_build_array(jsonb_build_object('response_code', '2000')),
       'active_session', json_input->'active_session'
   ));
END;
$function$;
