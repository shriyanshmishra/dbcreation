-- DROP FUNCTION production.check_entity_and_column_permissions(jsonb);

CREATE OR REPLACE FUNCTION production.check_entity_and_column_permissions(json_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    item jsonb;
    v_user_id varchar;
    v_session_token text := json_input->'active_session'->>'session_token';
    v_result jsonb := '[]'::jsonb;
    v_entity_id varchar;
    v_column_id varchar;
    v_matched_codes int[] := '{}';
BEGIN
    -- Get user_id from session token
    SELECT user_id INTO v_user_id
    FROM production.login_session_meta
    WHERE session_token = v_session_token AND is_active = true
    ORDER BY session_start DESC
    LIMIT 1;

    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object(
            'status', 'error',
            'message', 'Invalid or inactive session token'
        );
    END IF;

    -- Loop through input data
    FOR item IN SELECT * FROM jsonb_array_elements(json_input->'data') LOOP
        v_entity_id := item->>'entity_id';
        v_column_id := item->>'column_id';
        v_matched_codes := '{}';

        IF v_column_id IS NULL THEN
            -- Entity-level privileges: return privilege_code from privilege_meta
            SELECT array_agg(DISTINCT pm.privilege_code)
            INTO v_matched_codes
            FROM production.entity_privilege_meta ep
            JOIN production.privilege_meta pm ON ep.privilege_id = pm.privilege_id
            WHERE pm.user_id = v_user_id
              AND ep.entity_id = v_entity_id;
        ELSE
            -- Column-level privileges: return privilege_code from privilege_meta
            SELECT array_agg(DISTINCT pm.privilege_code)
            INTO v_matched_codes
            FROM production.column_privilege_meta cp
            JOIN production.privilege_meta pm ON cp.privilege_id = pm.privilege_id
            WHERE pm.user_id = v_user_id
              AND cp.entity_id = v_entity_id
              AND cp.column_id = v_column_id;
        END IF;

        -- Append to result
        v_result := v_result || jsonb_build_array(jsonb_build_object(
            'entity_id', v_entity_id,
            'column_id', v_column_id,
            'privilege_codes', coalesce(v_matched_codes, '{}')
        ));
    END LOOP;

    RETURN jsonb_build_object(
        'status', 'success',
        'user_id', v_user_id,
        'results', v_result
    );
END;
$function$
;
