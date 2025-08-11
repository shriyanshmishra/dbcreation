-- DROP FUNCTION production.validate_session_token(jsonb);

CREATE OR REPLACE FUNCTION production.validate_session_token(json_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_exists boolean;
    base_response jsonb;
    modified_response jsonb;
    v_session_token text;
BEGIN
    -- Step 0: Validate top-level keys
    IF NOT (json_input ? 'data_space' AND json_input ? 'meta_table' AND json_input ? 'data') THEN
        base_response := production.get_response_message('{
            "data": [
                { "error_code": "1001" }
            ],
            "active_session": null
        }'::jsonb);

        RETURN jsonb_build_object(
            'response', jsonb_build_array(
                (base_response->'response'->0) ||
                jsonb_build_object('params', to_jsonb(ARRAY['data_space', 'meta_table', 'data']))
            )
        );
    END IF;

    -- Step 0.5: Validate 'data' is an array
    IF jsonb_typeof(json_input->'data') <> 'array' THEN
        base_response := production.get_response_message('{
            "data": [
                { "error_code": "1002" }
            ],
            "active_session": null
        }'::jsonb);

        RETURN jsonb_build_object(
            'response', jsonb_build_array(
                (base_response->'response'->0) ||
                jsonb_build_object('params', to_jsonb(ARRAY['data']))
            )
        );
    END IF;

    -- Step 1: Validate 'data_space' and 'meta_table'
    IF (json_input->>'data_space') IS DISTINCT FROM 'production' OR
       (json_input->>'meta_table') IS DISTINCT FROM 'login' THEN

        base_response := production.get_response_message('{
            "data": [
                { "error_code": "1001" }
            ],
            "active_session": null
        }'::jsonb);

        RETURN jsonb_build_object(
            'response', jsonb_build_array(
                (base_response->'response'->0) ||
                jsonb_build_object('params', to_jsonb(ARRAY['data_space', 'meta_table']))
            )
        );
    END IF;

    -- Step 2: Extract session_token
    v_session_token := json_input->'data'->0->>'session_token';

    IF v_session_token IS NULL THEN
        base_response := production.get_response_message('{
            "data": [
                { "error_code": "1001" }
            ],
            "active_session": null
        }'::jsonb);

        RETURN jsonb_build_object(
            'response', jsonb_build_array(
                (base_response->'response'->0) ||
                jsonb_build_object('params', to_jsonb(ARRAY['session_token']))
            )
        );
    END IF;

    -- Step 3: Validate session_token
    SELECT EXISTS (
        SELECT 1
        FROM production.login_session_meta
        WHERE session_token = v_session_token
          AND is_active = TRUE
          AND (session_end IS NULL OR session_end > now())
    ) INTO v_exists;

    IF v_exists THEN
        -- Token valid: return null
        RETURN NULL;
    ELSE
        -- Token invalid or expired
        base_response := production.get_response_message('{
            "data": [
                { "error_code": "1306" }
            ],
            "active_session": null
        }'::jsonb);

        RETURN jsonb_build_object(
            'response', jsonb_build_array(
                (base_response->'response'->0) ||
                jsonb_build_object('params', to_jsonb(ARRAY['session_token']))
            )
        );
    END IF;
END;
$function$
;
