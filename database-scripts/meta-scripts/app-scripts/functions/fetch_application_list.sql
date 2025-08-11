-- DROP FUNCTION production.fetch_application_list(jsonb);

CREATE OR REPLACE FUNCTION production.fetch_application_list(input_json jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_data_space      TEXT;
    v_active_session  JSONB;
    v_session_token   TEXT;
    v_current_user_id TEXT;
    v_response_data   JSONB := '[]';
    v_app_record      RECORD;
BEGIN
    -- [STEP 1] Validate top-level structure
    IF input_json IS NULL 
        OR NOT input_json ? 'data_space' 
        OR NOT input_json ? 'active_session'
    THEN
        RETURN production.get_response_message(jsonb_build_object(
            'data', jsonb_build_array(jsonb_build_object('error_code', '1001')),
            'active_session', input_json -> 'active_session'
        ));
    END IF;

    v_data_space := input_json ->> 'data_space';
    v_active_session := input_json -> 'active_session';
    v_session_token := v_active_session ->> 'session_token';

    -- [STEP 2] Validate session
    SELECT user_id INTO v_current_user_id
    FROM production.login_session_meta
    WHERE session_token = v_session_token;

    IF v_current_user_id IS NULL THEN
        RETURN production.get_response_message(jsonb_build_object(
            'data', jsonb_build_array(jsonb_build_object('error_code', '1003')),
            'active_session', v_active_session
        ));
    END IF;

    -- [STEP 3] Build App List
    FOR v_app_record IN
        SELECT
            app_id,
            label,
            developer_name,
            COALESCE(description, '') AS description,
            COALESCE(updated_at, created_at) AS last_modified,
            navigation_style,
            form_factor,
            setup_experience
        FROM production.app_meta
        WHERE is_deleted = FALSE
          AND is_latest = TRUE
          AND is_active = TRUE
        ORDER BY label
    LOOP
        v_response_data := v_response_data || jsonb_build_object(
            'app_id', v_app_record.app_id,
            'label', v_app_record.label,
            'developer_name', v_app_record.developer_name,
            'description', v_app_record.description,
            'last_modified', to_char(v_app_record.last_modified, 'DD/MM/YYYY, HH12:MI AM'),
            'app_type', CASE 
                            WHEN v_app_record.navigation_style = 'console' THEN 'Console'
                            ELSE 'Standard'
                        END,
            'form_factor', v_app_record.form_factor,
            'setup_experience', v_app_record.setup_experience
        );
    END LOOP;

    -- [STEP 4] Return wrapped response
  RETURN v_response_data;

END;
$function$
;
