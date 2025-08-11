-- DROP FUNCTION production.generate_otp(jsonb);

/*
request
{
    "data_space": "production",
    "meta_table": "entity_meta",
    "active_session": {
        "session_token": "Default-session-for-testing"
    },
    "data": [
        {
            email : 'abc@gmail.com',
            locale : 'en_us'
        }
    ]
}
 */

/*
 {
    "status" : "SUCCESS",
    "otp_coe": "0123",
    "email" "abc@gmail.com"
 }

 {
    "status" : "ERROR",
    "message" : "ERROR Message"
 }


 */
CREATE OR REPLACE FUNCTION production.generate_otp(json_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  payload       JSONB := (json_input->'data')->0;
  v_email       TEXT   := payload->>'email';
  v_user_id     TEXT;
  v_plain       TEXT;
  v_hash        TEXT;
  email_result  JSONB;
  otp_response  JSONB;
BEGIN
  RAISE NOTICE 'STEP 1: Extracted payload = %', payload;
  RAISE NOTICE 'STEP 2: Email to check = %', v_email;

  -- 1. Call email_exists_function
  email_result := production.email_exists_function(
    jsonb_build_object(
      'data', jsonb_build_array(
        jsonb_build_object('email', v_email)
      )
    )
  );
  RAISE NOTICE 'STEP 3: email_exists_function result = %', email_result;

  -- 2. If error, bail out
  IF (email_result->'response'->0 ? 'error_code') THEN
    RAISE NOTICE 'STEP 4: Email not found, returning error envelope';
    RETURN email_result;
  END IF;
  RAISE NOTICE 'STEP 4: Email exists, proceeding to lookup user_id';

  -- 3. Fetch user_id
  SELECT user_id
    INTO v_user_id
  FROM production."user"
  WHERE email = v_email;
  RAISE NOTICE 'STEP 5: Retrieved user_id = %', v_user_id;

  -- 4. Generate OTP
  v_plain := LPAD((floor(random() * 1000000))::TEXT, 6, '0');
  RAISE NOTICE 'STEP 6: Generated plain OTP = %', v_plain;
  IF length(v_plain) <> 6 THEN
    RAISE NOTICE 'STEP 7: OTP generation failed, returning error 1302';
    RETURN production.get_error_message_code(
      jsonb_build_object('response', jsonb_build_array(
        jsonb_build_object('error_code','1302')
      ))
    );
  END IF;

  -- 5. Hash OTP
  v_hash := encode(digest(convert_to(v_plain,'UTF8'),'sha256'),'hex');
  RAISE NOTICE 'STEP 8: Hashed OTP = %', v_hash;

  -- 6. Store in user table
  UPDATE production."user"
     SET otp_hash       = v_hash,
         otp_expires_at = now() + INTERVAL '5 minutes',
         otp_used       = FALSE
   WHERE user_id = v_user_id;
  RAISE NOTICE 'STEP 9: Stored hash & expiry in user row';

  -- 7. Build success envelope
  otp_response := production.get_success_message_code(
    jsonb_build_object('response', jsonb_build_array(
      jsonb_build_object('success_code','2002')
    ))
  );
  RAISE NOTICE 'STEP 10: Base success envelope = %', otp_response;

  -- 8. Append params ["OTP"] & OTP value
  RAISE NOTICE 'STEP 11: Appending params ["OTP"] and plain OTP to envelope';
  RETURN jsonb_build_object(
    'response', jsonb_build_array(
      (otp_response->'response'->0)
        || jsonb_build_object(
             'params', to_jsonb(ARRAY['OTP']),
             'otp',    v_plain
           )
    )
  );

EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'UNEXPECTED ERROR at %: %', clock_timestamp(), SQLERRM;
  RETURN production.get_error_message_code(
    jsonb_build_object('response', jsonb_build_array(
      jsonb_build_object('LOGIN_OTP_EMAIL_SENT','1301')
    ))
  );
END;
$function$
;
