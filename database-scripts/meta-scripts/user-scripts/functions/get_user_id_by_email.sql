-- DROP FUNCTION production.get_user_id_by_email(jsonb);

CREATE OR REPLACE FUNCTION production.get_user_id_by_email(json_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    base_response jsonb;
    modified_response jsonb;
    v_user_id varchar(22);
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

    -- Step 1: Validate data_space and meta_table values
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

    -- Step 2: Try to get user_id from email
    SELECT user_id
    INTO v_user_id
    FROM production."user"
    WHERE email = (json_input->'data'->0->>'email');

    IF FOUND THEN
        modified_response := jsonb_build_object(
            'response', jsonb_build_array(
                jsonb_build_object(
                    'email', json_input->'data'->0->>'email',
                    'user_id', v_user_id
                    
                )
            )
        );

        RETURN modified_response;
    END IF;

    -- Step 3: If not found, return 1301
    base_response := production.get_response_message('{
        "data": [
            { "error_code": "1305" }
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
