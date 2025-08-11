-- DROP FUNCTION production.validate_token(jsonb);

CREATE OR REPLACE FUNCTION production.validate_token(json_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    payload jsonb := (json_input->'data')->0;
    v_token text := payload->>'token';
    v_session_id int;
    v_expiry timestamp;
    base_response jsonb;
BEGIN
    SELECT session_id, session_end
    INTO v_session_id, v_expiry
    FROM production.login_session_meta
    WHERE session_token = v_token
    LIMIT 1;

    IF NOT FOUND OR v_expiry < now() THEN
        -- Token is invalid or expired
        base_response := production.get_error_message_code('{
            "response": [
                { "error_code": "1304" }
            ]
        }'::jsonb);

        RETURN jsonb_build_object(
            'response', jsonb_build_array(
                (base_response->'response'->0) || jsonb_build_object('params', to_jsonb(ARRAY['Token']))
            )
        );
    END IF;

   
END;
$function$
;
