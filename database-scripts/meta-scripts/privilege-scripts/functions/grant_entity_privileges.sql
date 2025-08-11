-- DROP FUNCTION production.grant_entity_privileges(jsonb);

CREATE OR REPLACE FUNCTION production.grant_entity_privileges(json_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    item jsonb;
    p_entity_id varchar;
    p_bitmask int;
    v_user_id varchar;
    v_session_token text := json_input->'active_session'->>'session_token';
    v_effective_mask int := 0;
    v_bit int;
    v_privilege_id varchar(22);
    v_access_level text;
    v_granted text[] := '{}';
    v_column_id varchar(22);
    v_existing_privs int[];
    v_new_privs int[] := '{}';
    v_label text;
    v_dev_name text;
    v_privilege_set_id varchar(22);
    v_role_id varchar(22);
BEGIN
    v_privilege_set_id := json_input->>'privilege_set_id';

    -- ✅ Validate privilege_set_id
    IF v_privilege_set_id IS NULL OR NOT EXISTS (
        SELECT 1 FROM production.privilege_set_meta
        WHERE privilege_set_id = v_privilege_set_id
    ) THEN
        RETURN production.get_response_message(jsonb_build_object(
            'data', jsonb_build_array(jsonb_build_object(
                'error_code', '1907',
                'error_message', 'Invalid privilege_set_id'
            )),
            'active_session', json_input->'active_session'
        ));
    END IF;

    -- ✅ Validate input structure
    IF NOT (json_input ? 'data_space' AND json_input ? 'active_session' AND json_input ? 'data') THEN
        RETURN production.get_response_message(jsonb_build_object(
            'data', jsonb_build_array(jsonb_build_object('error_code', '1001')),
            'active_session', json_input->'active_session'
        ));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.schemata
        WHERE schema_name = json_input->>'data_space'
    ) THEN
        RETURN production.get_response_message(jsonb_build_object(
            'data', jsonb_build_array(jsonb_build_object('error_code', '1005')),
            'active_session', json_input->'active_session'
        ));
    END IF;

    -- ✅ Get user ID from session token
    SELECT user_id INTO v_user_id
    FROM production.login_session_meta
    WHERE session_token = v_session_token AND is_active = true
    ORDER BY session_start DESC
    LIMIT 1;

    IF v_user_id IS NULL THEN
        RETURN production.get_response_message(jsonb_build_object(
            'data', jsonb_build_array(jsonb_build_object('error_code', '1003')),
            'active_session', json_input->'active_session'
        ));
    END IF;

    -- ✅ Fetch role_id for the user
    SELECT role_id INTO v_role_id
    FROM production.user_role_meta
    WHERE user_id = v_user_id
    ORDER BY created_date DESC
    LIMIT 1;

    -- ✅ Loop through each entity
    FOR item IN SELECT * FROM jsonb_array_elements(json_input->'data') LOOP
        p_entity_id := item->>'entity_id';
        p_bitmask := (item->>'bitmask')::int;
        v_effective_mask := 0;
        v_new_privs := '{}';

        IF p_entity_id IS NULL OR trim(p_entity_id) = '' THEN
            RETURN production.get_response_message(jsonb_build_object(
                'data', jsonb_build_array(jsonb_build_object('error_code', '1006')),
                'active_session', json_input->'active_session'
            ));
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM production.entity_meta
            WHERE entity_id = p_entity_id
        ) THEN
            RETURN production.get_response_message(jsonb_build_object(
                'data', jsonb_build_array(jsonb_build_object('error_code', '1006')),
                'active_session', json_input->'active_session'
            ));
        END IF;

        -- Compute effective mask from bitmask
        IF (p_bitmask & 32) = 32 THEN
            v_effective_mask := v_effective_mask | 32 | 16 | 8 | 4 | 2 | 1;
        ELSIF (p_bitmask & 16) = 16 THEN
            v_effective_mask := v_effective_mask | 16 | 1;
        END IF;
        IF (p_bitmask & 8) = 8 THEN
            v_effective_mask := v_effective_mask | 8 | 4 | 1;
        ELSIF (p_bitmask & 4) = 4 THEN
            v_effective_mask := v_effective_mask | 4 | 1;
        ELSIF (p_bitmask & 2) = 2 THEN
            v_effective_mask := v_effective_mask | 2 | 1;
        ELSIF (p_bitmask & 1) = 1 THEN
            v_effective_mask := v_effective_mask | 1;
        END IF;
        IF (p_bitmask & 64) = 64 THEN
            v_effective_mask := v_effective_mask | 1;
        END IF;

        -- Get existing user privileges
        SELECT array_agg(pm.privilege_code)
        INTO v_existing_privs
        FROM production.entity_privilege_meta ep
        JOIN production.privilege_meta pm ON ep.privilege_id = pm.privilege_id
        WHERE ep.entity_id = p_entity_id AND pm.user_id = v_user_id;

        -- Grant bitwise privileges
        FOR v_bit IN 0..5 LOOP
            IF (v_effective_mask & (1 << v_bit)) > 0 THEN
                CASE v_bit
                    WHEN 0 THEN v_access_level := 'READ';
                    WHEN 1 THEN v_access_level := 'CREATE';
                    WHEN 2 THEN v_access_level := 'EDIT';
                    WHEN 3 THEN v_access_level := 'DELETE';
                    WHEN 4 THEN v_access_level := 'VIEW_ALL';
                    WHEN 5 THEN v_access_level := 'MODIFY_ALL';
                END CASE;

                INSERT INTO production.privilege_meta (
                    label, developer_name, privilege_code, user_id, privilege_set_id
                )
                SELECT initcap(v_access_level), v_access_level, (1 << v_bit), v_user_id, v_privilege_set_id
                WHERE NOT EXISTS (
                    SELECT 1 FROM production.privilege_meta
                    WHERE privilege_code = (1 << v_bit) AND user_id = v_user_id
                )
                RETURNING privilege_id INTO v_privilege_id;

                IF v_privilege_id IS NULL THEN
                    SELECT privilege_id INTO v_privilege_id
                    FROM production.privilege_meta
                    WHERE privilege_code = (1 << v_bit) AND user_id = v_user_id;
                END IF;

                IF v_privilege_id IS NOT NULL THEN
                    v_label := initcap(v_access_level) || ' - ' || v_user_id;
                    v_dev_name := lower(v_access_level) || '_usr_' || v_user_id;

                    -- Assign privilege to user
                    PERFORM 1 FROM production.user_privilege_assignment
                    WHERE privilege_id = v_privilege_id AND user_id = v_user_id;

                    IF NOT FOUND THEN
                        INSERT INTO production.user_privilege_assignment (
                            label, developer_name, privilege_id, user_id, created_by
                        ) VALUES (
                            v_label, v_dev_name, v_privilege_id, v_user_id, v_user_id
                        ) ON CONFLICT DO NOTHING;
                    END IF;

                    -- Assign privilege to entity
                    INSERT INTO production.entity_privilege_meta (
                        privilege_id, entity_id, access_level, created_by
                    ) VALUES (
                        v_privilege_id, p_entity_id, upper(v_access_level), v_user_id
                    ) ON CONFLICT DO NOTHING;

                    -- Map to privilege set
                    INSERT INTO production.privilege_set_mapping (
                        privilege_set_id, privilege_id, created_by
                    )
                    SELECT v_privilege_set_id, v_privilege_id, v_user_id
                    WHERE NOT EXISTS (
                        SELECT 1 FROM production.privilege_set_mapping
                        WHERE privilege_set_id = v_privilege_set_id AND privilege_id = v_privilege_id
                    );

                    v_new_privs := array_append(v_new_privs, (1 << v_bit));
                    v_granted := array_append(v_granted, upper(v_access_level));
                END IF;
            END IF;
        END LOOP;

        -- VIEW_ALL_FIELDS (bit 6)
        IF (p_bitmask & 64) = 64 THEN
            SELECT privilege_id INTO v_privilege_id
            FROM production.privilege_meta
            WHERE developer_name = 'READ' AND user_id = v_user_id;

            IF v_privilege_id IS NOT NULL THEN
                FOR v_column_id IN
                    SELECT column_id FROM production.column_meta
                    WHERE entity_id = p_entity_id
                LOOP
                    INSERT INTO production.column_privilege_meta (
                        privilege_id, entity_id, column_id, access_level, created_by
                    ) VALUES (
                        v_privilege_id, p_entity_id, v_column_id, 'READ', v_user_id
                    ) ON CONFLICT DO NOTHING;
                END LOOP;
                v_granted := array_append(v_granted, 'VIEW_ALL_FIELDS');
            END IF;
        END IF;

        -- Cleanup stale privileges
        DELETE FROM production.entity_privilege_meta
        WHERE entity_id = p_entity_id
          AND privilege_id IN (
              SELECT privilege_id FROM production.privilege_meta
              WHERE user_id = v_user_id
                AND privilege_code = ANY(v_existing_privs)
                AND privilege_code <> ALL(v_new_privs)
          );
    END LOOP;

    -- Remove orphaned privileges
    DELETE FROM production.privilege_meta pm
    WHERE pm.user_id = v_user_id
      AND NOT EXISTS (SELECT 1 FROM production.entity_privilege_meta ep WHERE ep.privilege_id = pm.privilege_id)
      AND NOT EXISTS (SELECT 1 FROM production.column_privilege_meta cp WHERE cp.privilege_id = pm.privilege_id)
      AND NOT EXISTS (SELECT 1 FROM production.system_privilege_meta sp WHERE sp.privilege_id = pm.privilege_id);

    -- Assign privilege_set to user
    INSERT INTO production.privilege_set_assignment (
        privilege_set_id, user_id, assigned_by
    )
    SELECT v_privilege_set_id, v_user_id, v_user_id
    WHERE NOT EXISTS (
        SELECT 1 FROM production.privilege_set_assignment
        WHERE privilege_set_id = v_privilege_set_id AND user_id = v_user_id
    );

    -- Assign privilege_set to role
    IF v_role_id IS NOT NULL THEN
        INSERT INTO production.privilege_set_assignment (
            privilege_set_id, role_id, assigned_by
        )
        SELECT v_privilege_set_id, v_role_id, v_user_id
        WHERE NOT EXISTS (
            SELECT 1 FROM production.privilege_set_assignment
            WHERE privilege_set_id = v_privilege_set_id AND role_id = v_role_id
        );
    END IF;

    RETURN jsonb_build_object(
        'status', 'success',
        'message', array_length(v_new_privs, 1) || ' privileges granted',
        'user_id', v_user_id,
        'role_id', v_role_id,
        'granted_access_levels', to_jsonb(ARRAY(SELECT DISTINCT p::text FROM unnest(v_new_privs) AS p)),
        'bitmask_used', v_effective_mask
    );
END;
$function$;
