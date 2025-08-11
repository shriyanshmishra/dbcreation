-- DROP FUNCTION production.email_exists_function(jsonb);

CREATE OR REPLACE FUNCTION production.email_exists_function(json_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    base_response jsonb;
    modified_response jsonb;
BEGIN
    -- Step 0: Validate top-level keys
    IF NOT (json_input ? 'data_space' AND json_input ? 'meta_table' AND json_input ? 'data') THEN
        base_response := production.get_response_message('{
            "data": [
                { "error_code": "1001" }
            ],
            "active_session": null
        }'::jsonb);

        modified_response := jsonb_build_object(
            'response', jsonb_build_array(
                (base_response->'response'->0) ||
                jsonb_build_object('params', to_jsonb(ARRAY['data_space', 'meta_table', 'data']))
            )
        );

        RETURN modified_response;
    END IF;

    -- Step 0.5: Validate data is an array
    IF jsonb_typeof(json_input->'data') <> 'array' THEN
        base_response := production.get_response_message('{
            "data": [
                { "error_code": "1002" }
            ],
            "active_session": null
        }'::jsonb);

        modified_response := jsonb_build_object(
            'response', jsonb_build_array(
                (base_response->'response'->0) ||
                jsonb_build_object('params', to_jsonb(ARRAY['data']))
            )
        );

        RETURN modified_response;
    END IF;

    -- Step 1: Validate specific values of data_space and meta_table
    IF (json_input->>'data_space') IS DISTINCT FROM 'production' AND
       (json_input->>'meta_table') IS DISTINCT FROM 'user' THEN

        base_response := production.get_response_message('{
            "data": [
                { "error_code": "1001" }
            ],
            "active_session": null
        }'::jsonb);

        modified_response := jsonb_build_object(
            'response', jsonb_build_array(
                (base_response->'response'->0) ||
                jsonb_build_object('params', to_jsonb(ARRAY['data_space', 'meta_table']))
            )
        );

        RETURN modified_response;
    END IF;

    -- Step 2: Proceed to email existence check
    IF EXISTS (
        SELECT 1 FROM production."user"
        WHERE email = (json_input->'data'->0->>'email')
    ) THEN
        base_response := production.get_response_message('{
            "data": [
                { "success_code": "2001" }
            ],
            "active_session": null
        }'::jsonb);

        modified_response := jsonb_build_object(
            'response', jsonb_build_array(
                (base_response->'response'->0) ||
                jsonb_build_object('params', to_jsonb(ARRAY['Email']))
            )
        );

        RETURN modified_response;
    END IF;

    -- Step 3: If email not found
    base_response := production.get_response_message('{
        "data": [
            { "error_code": "1301" }
        ],
        "active_session": null
    }'::jsonb);

    modified_response := jsonb_build_object(
        'response', jsonb_build_array(
            (base_response->'response'->0) ||
            jsonb_build_object('params', to_jsonb(ARRAY['Email']))
        )
    );

    RETURN modified_response;
END;
$function$
;
