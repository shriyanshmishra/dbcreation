-- DROP FUNCTION production.create_privilege_set(jsonb);

CREATE OR REPLACE FUNCTION production.create_privilege_set(json_input jsonb)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    item jsonb;
    v_label varchar(255);
    v_developer_name varchar(255);
    v_description text;
    v_created_by varchar(22);
    v_last_modified_by varchar(22);
    v_privilege_set_id varchar(22);
    current_user_id varchar(22);
    v_existing_id varchar(22);
    v_session_activation boolean;
    v_role_id varchar(22);
    successful_inserts jsonb := '[]'::jsonb;
    failed_inserts jsonb := '[]'::jsonb;
    v_view_name text;
    v_view_sql text;
BEGIN
    IF NOT (json_input ? 'data_space' AND json_input ? 'active_session' AND json_input ? 'data') THEN
        RETURN production.get_response_message(jsonb_build_object('data', jsonb_build_array(jsonb_build_object('error_code', '1001')), 'active_session', json_input->'active_session'));
    END IF;

    IF jsonb_typeof(json_input->'data') <> 'array' THEN
        RETURN production.get_response_message(jsonb_build_object('data', jsonb_build_array(jsonb_build_object('error_code', '1002')), 'active_session', json_input->'active_session'));
    END IF;

    SELECT user_id INTO current_user_id
    FROM production.login_session_meta
    WHERE session_token = json_input->'active_session'->>'session_token';

    IF current_user_id IS NULL THEN
        RETURN production.get_response_message(jsonb_build_object('data', jsonb_build_array(jsonb_build_object('error_code', '1003')), 'active_session', json_input->'active_session'));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.schemata
        WHERE schema_name = json_input->>'data_space'
    ) THEN
        RETURN production.get_response_message(jsonb_build_object('data', jsonb_build_array(jsonb_build_object('error_code', '1005')), 'active_session', json_input->'active_session'));
    END IF;

    FOR item IN SELECT * FROM jsonb_array_elements(json_input->'data') LOOP
        BEGIN
            v_label := item ->> 'label';
            v_developer_name := production.remove_special_characters(item ->> 'developer_name');
            v_description := item ->> 'description';
            v_created_by := COALESCE(NULLIF(item ->> 'created_by', ''), current_user_id);
            v_last_modified_by := COALESCE(NULLIF(item ->> 'last_modified_by', ''), current_user_id);
            v_session_activation := (item->>'session_activation_required')::boolean;
            v_role_id := item ->> 'role_id';

            IF v_label IS NULL OR v_label = '' THEN
                RAISE NOTICE 'Missing label for item: %', item;
                failed_inserts := failed_inserts || jsonb_build_array(jsonb_build_object('error_code', '1801', 'developer_name', v_developer_name));
                CONTINUE;
            END IF;

            IF v_developer_name IS NULL OR v_developer_name = '' THEN
                RAISE NOTICE 'Missing developer_name for item: %', item;
                failed_inserts := failed_inserts || jsonb_build_array(jsonb_build_object('error_code', '1802', 'label', v_label));
                CONTINUE;
            END IF;

            -- Check for duplicate developer_name
            SELECT privilege_set_id INTO v_existing_id
            FROM production.privilege_set_meta
            WHERE developer_name = v_developer_name;

            IF v_existing_id IS NOT NULL THEN
                failed_inserts := failed_inserts || jsonb_build_array(jsonb_build_object('error_code', '1803', 'developer_name', v_developer_name));
                CONTINUE;
            END IF;

            -- Insert
            INSERT INTO production.privilege_set_meta (
                label, developer_name, description,
                created_by, last_modified_by,
                session_activation_required, role_id
            ) VALUES (
                v_label, v_developer_name, v_description,
                v_created_by, v_last_modified_by,
                v_session_activation, v_role_id
            )
            RETURNING privilege_set_id INTO v_privilege_set_id;

            v_view_name := lower('ps_view_' || v_privilege_set_id);
            v_view_sql := format(
                'CREATE OR REPLACE VIEW %I.%I AS
                 SELECT label AS "Permission Set Name", description AS "Description"
                 FROM %I.privilege_set_meta
                 WHERE privilege_set_id = %L;',
                 json_input->>'data_space',
                 v_view_name,
                 json_input->>'data_space',
                 v_privilege_set_id
            );

            EXECUTE v_view_sql;

            successful_inserts := successful_inserts || jsonb_build_array(
                jsonb_build_object('privilege_set_id', v_privilege_set_id, 'view_name', v_view_name)
            );
        EXCEPTION WHEN OTHERS THEN
            failed_inserts := failed_inserts || jsonb_build_array(jsonb_build_object('error_code', '9999', 'message', SQLERRM));
        END;
    END LOOP;
  RETURN production.get_response_message(
    jsonb_build_object(
        'data', jsonb_build_array(jsonb_build_object('response_code', 2006)),
        'active_session', json_input->'active_session'
    )
);

END;
$function$
;
