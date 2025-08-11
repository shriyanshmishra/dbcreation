-- DROP FUNCTION production.get_response_message(jsonb);

CREATE OR REPLACE FUNCTION production.get_response_message(input_json jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_session_token TEXT;
  v_user_id      TEXT;
  v_locale       TEXT;
  v_code         TEXT;
  v_code_int     INT;
  v_message      TEXT;
  v_code_key     TEXT;
BEGIN
  -- Extract optional session token
  v_session_token := input_json -> 'active_session' ->> 'session_token';
  RAISE NOTICE 'Extracted session token: %', v_session_token;

  -- Determine locale: if session token provided, look up user; otherwise use default
  IF v_session_token IS NOT NULL THEN
    -- Validate session token and get user_id
    SELECT user_id INTO v_user_id
      FROM production.login_session_meta
     WHERE session_token = v_session_token;
    RAISE NOTICE 'Session lookup user_id: %', v_user_id;

    IF v_user_id IS NULL THEN
      RAISE NOTICE 'Invalid or expired session token, returning error';
      RETURN jsonb_build_object('response', jsonb_build_array(
        jsonb_build_object('error', 'Invalid or expired session token')
      ));
    END IF;

    -- Get user locale
   SELECT COALESCE(u."language", 'en_US') INTO v_locale
   FROM production."user" u
   WHERE u.user_id = v_user_id;

    RAISE NOTICE 'Determined locale from user: %', v_locale;
  ELSE
    -- No session: force default locale
    v_locale := NULL;
    RAISE NOTICE 'No session token provided, will use default locale';
  END IF;

  -- Validate data array payload
  IF jsonb_typeof(input_json->'data') <> 'array' OR jsonb_array_length(input_json->'data') = 0 THEN
    RAISE NOTICE 'Invalid or empty data payload, returning error';
    RETURN jsonb_build_object('response', jsonb_build_array(
      jsonb_build_object('error', 'Invalid data payload')
    ));
  END IF;
  RAISE NOTICE 'Data payload is valid';

  -- Extract code key
  SELECT key INTO v_code_key
    FROM jsonb_object_keys(input_json->'data'->0) AS key
   LIMIT 1;
  RAISE NOTICE 'Extracted code key: %', v_code_key;

  -- Extract and cast code value
  v_code := input_json->'data'->0->>v_code_key;
  RAISE NOTICE 'Extracted code text: %', v_code;
  BEGIN
    v_code_int := v_code::int;
    RAISE NOTICE 'Parsed code integer: %', v_code_int;
  EXCEPTION WHEN others THEN
    RAISE NOTICE 'Failed to parse code to integer, returning error';
    RETURN jsonb_build_object('response', jsonb_build_array(
      jsonb_build_object('error', 'Code value is not a valid integer')
    ));
  END;

  -- Attempt localized lookup if locale is known
  IF v_locale IS NOT NULL THEN
    SELECT response_message INTO v_message
      FROM production.response_messages
     WHERE response_code = v_code_int
       AND locale = v_locale
     LIMIT 1;
    RAISE NOTICE 'Localized message lookup result: %', v_message;
  END IF;

  -- Fallback to default locale if needed
  IF v_message IS NULL THEN
    SELECT response_message INTO v_message
      FROM production.response_messages
     WHERE response_code = v_code_int
       AND is_default = true
     LIMIT 1;
    RAISE NOTICE 'Default locale message lookup result: %', v_message;
  END IF;

  -- Final fallback
  IF v_message IS NULL THEN
    v_message := 'Message not found';
    RAISE NOTICE 'No message found in database, using fallback text';
  END IF;

  -- Build and return JSON
  RAISE NOTICE 'Building response JSON with key % and message %', v_code_key, v_message;
  RETURN jsonb_build_object('response', jsonb_build_array(
    jsonb_build_object(
      v_code_key, v_code,
      CASE
        WHEN v_code_key ILIKE '%error_code%'   THEN 'error_message'
        WHEN v_code_key ILIKE '%success_code%' THEN 'success_message'
        ELSE 'response_message'
      END, v_message
    )
  ));
END;
$function$
;
