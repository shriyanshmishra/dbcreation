-- DROP FUNCTION production.create_application(jsonb);

CREATE OR REPLACE FUNCTION production.create_application(input_json jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_data_space       TEXT;
  v_active_session   JSONB;
  v_data             JSONB;
  v_rec              JSONB;
  v_label            TEXT;
  v_developer_name   TEXT;
  v_description      TEXT;
  v_app_id           TEXT;
  v_app_key          BIGINT;
  v_created_by       TEXT;
  v_result           JSONB;

  v_tabs_payload     JSONB;
  v_priv_payload     JSONB;
  v_tab_ids          JSONB;
  v_priv_ids         JSONB;
  v_priv_set_ids     JSONB;

  v_tab_result       JSONB;
  v_priv_result      JSONB;
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

  -- STEP 2: Resolve session user
  RAISE NOTICE '[STEP 2] Resolving session user...';
  SELECT user_id INTO v_created_by
  FROM production.login_session_meta
  WHERE session_token = v_active_session->>'session_token' AND is_active = true;

  IF v_created_by IS NULL THEN
    RAISE NOTICE '[ERROR] Invalid or inactive session token.';
    RETURN jsonb_build_object(
      'status', jsonb_build_object(
        'error_code', '1003',
        'error_message', 'Invalid or inactive session token.'
      )
    );
  END IF;
  RAISE NOTICE '[INFO] Session resolved. User ID: %', v_created_by;

  -- STEP 3: Validate "data" payload
  IF jsonb_typeof(v_data) <> 'array' THEN
    RAISE NOTICE '[ERROR] "data" field must be a JSON array.';
    RETURN jsonb_build_object(
      'status', jsonb_build_object(
        'error_code', '1002',
        'error_message', 'Data must be an array.'
      )
    );
  END IF;

  -- STEP 4: Process the first record
  v_rec := v_data->0;
  v_label := v_rec->>'label';
  v_developer_name := v_rec->>'developer_name';
  v_description := v_rec->>'description';

  RAISE NOTICE '[STEP 4] Processing application with developer_name: %', v_developer_name;

  -- Validate required fields
  IF v_label IS NULL OR v_developer_name IS NULL THEN
    RAISE NOTICE '[ERROR] Missing label or developer_name.';
    RETURN jsonb_build_object(
      'status', jsonb_build_object(
        'error_code', '1700',
        'error_message', 'Missing required fields: label or developer_name.'
      )
    );
  END IF;

  -- Check for duplicate developer_name
  IF EXISTS (
    SELECT 1 FROM production.app_meta
    WHERE developer_name = v_developer_name AND is_deleted = false
  ) THEN
    RAISE NOTICE '[ERROR] Duplicate developer_name detected: %', v_developer_name;
    RETURN jsonb_build_object(
      'status', jsonb_build_object(
        'error_code', '1701',
        'error_message', 'Developer name already exists.'
      )
    );
  END IF;

  -- STEP 5: Insert new app
  RAISE NOTICE '[STEP 5] Inserting new application...';
  INSERT INTO production.app_meta (
    label, developer_name, description,
    icon, primary_color_hex, form_factor, navigation_style, setup_experience,
    use_custom_theme, disable_nav_personalization, disable_temp_tabs, use_omni_channel_sidebar,
    created_by, created_by_session, updated_by, updated_by_session
  )
  VALUES (
    v_label,
    v_developer_name,
    v_description,
    decode(v_rec->>'icon', 'base64'),
    COALESCE(v_rec->>'primary_color_hex', '#0070D2'),
    COALESCE(v_rec->>'form_factor', 'both'),
    COALESCE(v_rec->>'navigation_style', 'standard'),
    COALESCE(v_rec->>'setup_experience', 'full'),
    (v_rec->>'use_custom_theme')::BOOLEAN,
    (v_rec->>'disable_nav_personalization')::BOOLEAN,
    (v_rec->>'disable_temp_tabs')::BOOLEAN,
    (v_rec->>'use_omni_channel_sidebar')::BOOLEAN,
    v_created_by,
    v_active_session->>'session_token',
    v_created_by,
    v_active_session->>'session_token'
  )
  RETURNING app_id, app_key INTO v_app_id, v_app_key;
  RAISE NOTICE '[INFO] New app created with app_id: %', v_app_id;

  -- STEP 6: Assign tabs if provided
  IF v_rec ? 'tab_ids' THEN
    RAISE NOTICE '[STEP 6] Assigning tabs to app...';
    v_tab_ids := v_rec -> 'tab_ids';
    v_tabs_payload := jsonb_build_object(
      'data_space', v_data_space,
      'active_session', v_active_session,
      'data', jsonb_build_array(jsonb_build_object(
        'app_id', v_app_id,
        'tab_ids', v_tab_ids
      ))
    );
    v_tab_result := production.assign_tabs_to_app(v_tabs_payload);
  END IF;

  -- STEP 7: Assign privileges if provided
  IF v_rec ? 'privilege_ids' OR v_rec ? 'privilege_set_ids' THEN
    RAISE NOTICE '[STEP 7] Assigning privileges to app...';
    v_priv_ids := COALESCE(v_rec -> 'privilege_ids', '[]');
    v_priv_set_ids := COALESCE(v_rec -> 'privilege_set_ids', '[]');
    v_priv_payload := jsonb_build_object(
      'data_space', v_data_space,
      'active_session', v_active_session,
      'data', jsonb_build_array(jsonb_build_object(
        'app_id', v_app_id,
        'privilege_ids', v_priv_ids,
        'privilege_set_ids', v_priv_set_ids
      ))
    );
    v_priv_result := production.assign_privileges_to_app(v_priv_payload);
  END IF;

  -- STEP 8: Prepare localized success message
  RAISE NOTICE '[STEP 8] Fetching localized success message...';
  v_result := production.get_response_message(jsonb_build_object(
    'data', jsonb_build_array(jsonb_build_object('code_key', 2011)),
    'active_session', v_active_session
  ));

  RAISE NOTICE '[SUCCESS] Application created successfully. App ID: %', v_app_id;
  RETURN jsonb_build_object(
    'status', jsonb_build_object(
      'response_code', '2011',
      'response_message', v_result->'response'->>'response_message'
    ),
    'data', jsonb_build_object(
      'app_id', v_app_id
    )
  );

EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE '[ERROR] Unexpected error: %', SQLERRM;
    RETURN jsonb_build_object(
      'status', jsonb_build_object(
        'error_code', '1705',
        'error_message', SQLERRM
      )
    );
END;
$function$
;
