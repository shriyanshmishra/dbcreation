-- DROP FUNCTION production.validate_application(jsonb);

CREATE OR REPLACE FUNCTION production.validate_application(input_json jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_data_space TEXT;
  v_active_session JSONB;
  v_session_token TEXT;
  v_data JSONB;
  v_rec JSONB;
  v_label TEXT;
  v_developer_name TEXT;
  v_navigation_style TEXT;
  v_form_factor TEXT;
  v_setup_experience TEXT;
  v_primary_color_hex TEXT;
  v_result JSONB;
BEGIN
  -- STEP 1: Validate top-level keys
  RAISE NOTICE '[STEP 1] Validating top-level keys...';
  IF NOT input_json ? 'data_space' OR NOT input_json ? 'active_session' OR NOT input_json ? 'data' THEN
    RAISE NOTICE '[ERROR] Missing top-level keys: data_space, active_session, or data.';
    RETURN jsonb_build_object(
      'status', jsonb_build_object(
        'error_code', '1001',
        'error_message', 'Missing required top-level keys.'
      )
    );
  END IF;

  v_data_space := input_json->>'data_space';
  v_active_session := input_json->'active_session';
  v_data := input_json->'data';

  -- STEP 2: Validate session token
  RAISE NOTICE '[STEP 2] Validating session token...';
  v_session_token := v_active_session->>'session_token';
  IF NOT EXISTS (
    SELECT 1 FROM production.login_session_meta
    WHERE session_token = v_session_token AND is_active = TRUE
  ) THEN
    RAISE NOTICE '[ERROR] Invalid or inactive session token: %', v_session_token;
    RETURN jsonb_build_object(
      'status', jsonb_build_object(
        'error_code', '1003',
        'error_message', 'Invalid or inactive session token.'
      )
    );
  END IF;

  -- STEP 3: Validate "data" payload
  RAISE NOTICE '[STEP 3] Validating "data" payload...';
  IF jsonb_typeof(v_data) <> 'array' THEN
    RAISE NOTICE '[ERROR] "data" must be an array.';
    RETURN jsonb_build_object(
      'status', jsonb_build_object(
        'error_code', '1002',
        'error_message', '"data" must be an array.'
      )
    );
  END IF;

  -- STEP 4: Validate the first record (only 1 allowed here)
  v_rec := v_data->0;
  v_label := v_rec->>'label';
  v_developer_name := v_rec->>'developer_name';
  v_navigation_style := v_rec->>'navigation_style';
  v_form_factor := v_rec->>'form_factor';
  v_setup_experience := v_rec->>'setup_experience';
  v_primary_color_hex := v_rec->>'primary_color_hex';

  -- Validate required label
  IF v_label IS NULL OR trim(v_label) = '' THEN
    RAISE NOTICE '[ERROR] Missing label in record.';
    RETURN jsonb_build_object(
      'status', jsonb_build_object(
        'error_code', '1742',
        'error_message', 'App label is required.'
      )
    );
  END IF;

  -- Validate unique developer_name (if provided)
  IF v_developer_name IS NOT NULL THEN
    IF EXISTS (
      SELECT 1 FROM production.app_meta
      WHERE LOWER(developer_name) = LOWER(v_developer_name) AND is_deleted = FALSE
    ) THEN
      RAISE NOTICE '[ERROR] Duplicate developer_name found: %', v_developer_name;
      RETURN jsonb_build_object(
        'status', jsonb_build_object(
          'error_code', '1721',
          'error_message', 'App developer name already exists (case-insensitive).'
        )
      );
    END IF;
  END IF;

  -- Validate navigation_style
  IF v_navigation_style IS NOT NULL AND v_navigation_style NOT IN ('standard', 'console') THEN
    RAISE NOTICE '[ERROR] Invalid navigation_style provided: %', v_navigation_style;
    RETURN jsonb_build_object(
      'status', jsonb_build_object(
        'error_code', '1733',
        'error_message', 'Invalid navigation_style (must be standard or console).'
      )
    );
  END IF;

  -- Validate form_factor
  IF v_form_factor IS NOT NULL AND v_form_factor NOT IN ('desktop', 'phone', 'both') THEN
    RAISE NOTICE '[ERROR] Invalid form_factor provided: %', v_form_factor;
    RETURN jsonb_build_object(
      'status', jsonb_build_object(
        'error_code', '1736',
        'error_message', 'Invalid form_factor (must be desktop, phone, or both).'
      )
    );
  END IF;

  -- Validate setup_experience
  IF v_setup_experience IS NOT NULL AND v_setup_experience NOT IN ('full', 'service') THEN
    RAISE NOTICE '[ERROR] Invalid setup_experience provided: %', v_setup_experience;
    RETURN jsonb_build_object(
      'status', jsonb_build_object(
        'error_code', '1734',
        'error_message', 'Invalid setup_experience (must be full or service).'
      )
    );
  END IF;

  -- Validate primary_color_hex
  IF v_primary_color_hex IS NOT NULL AND NOT (v_primary_color_hex ~* '^#[0-9A-Fa-f]{6}$') THEN
    RAISE NOTICE '[ERROR] Invalid primary_color_hex provided: %', v_primary_color_hex;
    RETURN jsonb_build_object(
      'status', jsonb_build_object(
        'error_code', '1735',
        'error_message', 'Invalid hex code for primary_color_hex.'
      )
    );
  END IF;

  -- STEP 5: Success Response
  RAISE NOTICE '[SUCCESS] All validations passed successfully.';
  v_result := production.get_response_message(jsonb_build_object(
    'data', jsonb_build_array(jsonb_build_object('code_key', 2017)),
    'active_session', v_active_session
  ));
  RETURN jsonb_build_object(
    'status', jsonb_build_object(
      'response_code', '2017',
      'response_message', v_result->'response'->>'response_message'
    )
  );

EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE '[ERROR] Unexpected error during validation: %', SQLERRM;
    RETURN jsonb_build_object(
      'status', jsonb_build_object(
        'error_code', '1740',
        'error_message', 'Unexpected error during validation: ' || SQLERRM
      )
    );
END;
$function$
;
