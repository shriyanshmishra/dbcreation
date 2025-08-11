-- DROP FUNCTION production.grant_entity_and_column_privileges(jsonb);

CREATE OR REPLACE FUNCTION production.grant_entity_and_column_privileges(json_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    item jsonb;
    entity_data jsonb := '[]'::jsonb;
    column_data jsonb := '[]'::jsonb;
    entity_result jsonb := '{}'::jsonb;
    column_result jsonb := '{}'::jsonb;
    v_data_space text := json_input->>'data_space';
    v_session jsonb := json_input->'active_session';
    entity_privilege_codes int[] := '{}';
    column_privilege_codes int[] := '{}';
    v_user_id text := null;
BEGIN
    -- Validate input
    IF NOT (
        json_input ? 'data_space' AND 
        json_input ? 'active_session' AND 
        json_input ? 'data'
    ) THEN
        RETURN production.get_response_message(jsonb_build_object(
            'data', jsonb_build_array(jsonb_build_object('error_code', '1001')),
            'active_session', json_input->'active_session'
        ));
    END IF;

    -- Separate column and entity level privileges
    FOR item IN SELECT * FROM jsonb_array_elements(json_input->'data') LOOP
        IF item ? 'column_id' THEN
            column_data := column_data || jsonb_build_array(item);
        ELSE
            entity_data := entity_data || jsonb_build_array(item);
        END IF;
    END LOOP;

    -- Call entity-level privilege function
    IF jsonb_array_length(entity_data) > 0 THEN
        entity_result := production.grant_entity_privileges(
            jsonb_build_object(
                'data_space', v_data_space,
                'active_session', v_session,
                'data', entity_data
            )
        );

        v_user_id := entity_result->>'user_id';

        BEGIN
            SELECT ARRAY(
                SELECT DISTINCT (value)::int
                FROM jsonb_array_elements_text(entity_result->'granted_access_levels')
                ORDER BY (value)::int
            ) INTO entity_privilege_codes;
        EXCEPTION WHEN OTHERS THEN
            entity_privilege_codes := '{}';
        END;
    END IF;

    -- Call column-level privilege function
    IF jsonb_array_length(column_data) > 0 THEN
        column_result := production.grant_column_privileges_with_bitmask(
            jsonb_build_object(
                'data_space', v_data_space,
                'active_session', v_session,
                'data', column_data
            )
        );

        IF v_user_id IS NULL THEN
            v_user_id := column_result->>'user_id';
        END IF;

        BEGIN
            SELECT ARRAY(
                SELECT DISTINCT (value)::int
                FROM jsonb_array_elements_text(column_result->'granted_access_levels')
                ORDER BY (value)::int
            ) INTO column_privilege_codes;
        EXCEPTION WHEN OTHERS THEN
            column_privilege_codes := '{}';
        END;
    END IF;

    -- Final response
    RETURN jsonb_build_object(
        'status', 'success',
        'user_id', v_user_id,
        'entity_result', entity_result,
        'column_result', column_result,
        'entity_privilege_code', to_jsonb(entity_privilege_codes),
        'column_privilege_code', to_jsonb(column_privilege_codes)
    );
END;
$function$
;
