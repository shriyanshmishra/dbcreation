-- DROP FUNCTION production.validate_otp(jsonb);

CREATE OR REPLACE FUNCTION production.validate_otp(json_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    payload       JSONB := (json_input->'data')->0;
    v_email       TEXT  := payload->>'email';
    v_code        TEXT  := payload->>'otp_code';
    v_hash        TEXT;
    v_rec         RECORD;
    base_response JSONB;
    modified_response JSONB;
BEGIN
    -- Step 1: Validate input presence
    RAISE NOTICE 'Step 1: Input email=%, otp_code=%', v_email, v_code;
    IF v_email IS NULL OR v_code IS NULL THEN
        RAISE NOTICE 'Step 1: Missing email or otp_code, returning error 1304';
        RETURN production.get_error_message_code('{
            "response": [
                { "error_code": "1304" }
            ]
        }'::jsonb);
    END IF;

    -- Step 2: Compute hash of submitted code
    v_hash := encode(digest(convert_to(v_code, 'UTF8'), 'sha256'), 'hex');
    RAISE NOTICE 'Step 2: Computed hash=% for otp_code=%', v_hash, v_code;

    -- Step 3: Fetch stored OTP details by email
    RAISE NOTICE 'Step 3: Fetching OTP details for email %', v_email;
    SELECT otp_hash, otp_expires_at, otp_used
      INTO v_rec
      FROM production."user"
     WHERE email = v_email;
    RAISE NOTICE 'Step 3: Retrieved otp_hash=%, otp_expires_at=%, otp_used=%',
                 v_rec.otp_hash, v_rec.otp_expires_at, v_rec.otp_used;

    -- Step 4: Validate existence, expiry, and usage
    IF NOT FOUND OR v_rec.otp_hash IS NULL OR v_rec.otp_used OR v_rec.otp_expires_at < now() THEN
        RAISE NOTICE 'Step 4: OTP invalid or expired, returning error 1303';
        base_response := production.get_error_message_code('{
            "response": [
                { "error_code": "1303" }
            ]
        }'::jsonb);

        modified_response := jsonb_build_object(
            'response', jsonb_build_array(
                (base_response->'response'->0) || jsonb_build_object('params', to_jsonb(ARRAY['Email']))
            )
        );

        RETURN modified_response;
    END IF;

    -- Step 5: Compare hashes
    RAISE NOTICE 'Step 5: Comparing hash';
    IF v_rec.otp_hash <> v_hash THEN
        RAISE NOTICE 'Step 5: OTP mismatch for email %, returning error 1303', v_email;
        base_response := production.get_error_message_code('{
            "response": [
                { "error_code": "1303" }
            ]
        }'::jsonb);

        modified_response := jsonb_build_object(
            'response', jsonb_build_array(
                (base_response->'response'->0) || jsonb_build_object('params', to_jsonb(ARRAY['Email']))
            )
        );

        RETURN modified_response;
    END IF;

    -- Step 6: Mark OTP as used
    RAISE NOTICE 'Step 6: Marking OTP as used for email %', v_email;
    UPDATE production."user"
       SET otp_used = TRUE
     WHERE email = v_email;

    -- Step 7: Return success envelope
    RAISE NOTICE 'Step 7: OTP validated successfully for email %, returning success', v_email;
    base_response := production.get_success_message_code('{
        "response": [
            { "success_code": "2003" }
        ]
    }'::jsonb);

    modified_response := jsonb_build_object(
        'response', jsonb_build_array(
            (base_response->'response'->0) || jsonb_build_object('params', to_jsonb(ARRAY['Email']))
        )
    );

    RETURN modified_response;

EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Exception occurred: %', SQLERRM;
    RETURN production.get_error_message_code('{
        "response": [
            { "error_code": "1301" }
        ]
    }'::jsonb);
END;
$function$
;
