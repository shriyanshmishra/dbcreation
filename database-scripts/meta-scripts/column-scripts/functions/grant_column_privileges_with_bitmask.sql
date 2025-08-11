-- DROP FUNCTION production.grant_column_privileges_with_bitmask(jsonb);

CREATE OR REPLACE FUNCTION production.grant_column_privileges_with_bitmask(json_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
   item jsonb;
   v_session_token TEXT;
   v_user_id VARCHAR(22);
   v_entity_id VARCHAR(22);
   v_column_id VARCHAR(22);
   v_bitmask INT;
   v_effective_mask INT;
   v_access_level TEXT;
   v_existing_privs INT[] := '{}';
   v_new_privs INT[] := '{}';
   v_granted TEXT[] := '{}';
   v_privilege_id VARCHAR(22);
   v_privilege_code INT;
   v_label TEXT;
   v_dev_name TEXT;
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

   -- ✅ Validate base input
   IF NOT (
       json_input ? 'data_space' AND 
       json_input ? 'active_session' AND 
       json_input ? 'data'
   ) THEN
       RETURN production.get_response_message(
           jsonb_build_object(
               'data', jsonb_build_array(jsonb_build_object('error_code', '1001')),
               'active_session', json_input->'active_session'
           )
       );
   END IF;

   IF jsonb_typeof(json_input->'data') <> 'array' THEN
       RETURN production.get_response_message(
           jsonb_build_object(
               'data', jsonb_build_array(jsonb_build_object('error_code', '1002')),
               'active_session', json_input->'active_session'
           )
       );
   END IF;

   v_session_token := json_input->'active_session'->>'session_token';
   SELECT user_id INTO v_user_id
   FROM production.login_session_meta
   WHERE session_token = v_session_token AND is_active = TRUE
   LIMIT 1;

   IF v_user_id IS NULL THEN
       RETURN production.get_response_message(
           jsonb_build_object(
               'data', jsonb_build_array(jsonb_build_object('error_code', '1003')),
               'active_session', json_input->'active_session'
           )
       );
   END IF;

   IF NOT EXISTS (
       SELECT 1 FROM information_schema.schemata 
       WHERE schema_name = json_input->>'data_space'
   ) THEN
       RETURN production.get_response_message(
           jsonb_build_object(
               'data', jsonb_build_array(jsonb_build_object('error_code', '1005')),
               'active_session', json_input->'active_session'
           )
       );
   END IF;

   -- Validate column-level entities
   FOR item IN SELECT * FROM jsonb_array_elements(json_input->'data')
   LOOP
       v_entity_id := item->>'entity_id';
       v_column_id := item->>'column_id';

       IF v_entity_id IS NULL OR trim(v_entity_id) = '' OR
          NOT EXISTS (SELECT 1 FROM production.entity_meta WHERE entity_id = v_entity_id) THEN
           RETURN production.get_response_message(
               jsonb_build_object(
                   'data', jsonb_build_array(jsonb_build_object('error_code', '1006')),
                   'active_session', json_input->'active_session'
               )
           );
       END IF;

       IF v_column_id IS NULL OR trim(v_column_id) = '' OR
          NOT EXISTS (
              SELECT 1 FROM production.column_meta
              WHERE column_id = v_column_id AND entity_id = v_entity_id
          ) THEN
           RETURN production.get_response_message(
               jsonb_build_object(
                   'data', jsonb_build_array(jsonb_build_object('error_code', '1007')),
                   'active_session', json_input->'active_session'
               )
           );
       END IF;
   END LOOP;

   -- Grant column-level privileges
   FOR item IN SELECT * FROM jsonb_array_elements(json_input->'data')
   LOOP
       v_entity_id := item->>'entity_id';
       v_column_id := item->>'column_id';
       v_bitmask := (item->>'bitmask')::INT;
       v_effective_mask := 0;

       IF (v_bitmask & 2) = 2 THEN
           v_effective_mask := 3;
       ELSIF (v_bitmask & 1) = 1 THEN
           v_effective_mask := 1;
       END IF;

       SELECT array_agg(pm.privilege_code)
       INTO v_existing_privs
       FROM production.column_privilege_meta cp
       JOIN production.privilege_meta pm ON cp.privilege_id = pm.privilege_id
       WHERE cp.entity_id = v_entity_id
         AND cp.column_id = v_column_id
         AND pm.user_id = v_user_id;

       IF v_existing_privs IS NOT NULL THEN
           IF 3 = ANY(v_existing_privs) AND (v_effective_mask & 2) = 0 THEN
               DELETE FROM production.column_privilege_meta
               WHERE entity_id = v_entity_id
                 AND column_id = v_column_id
                 AND access_level = 'EDIT'
                 AND privilege_id IN (
                     SELECT privilege_id FROM production.privilege_meta
                     WHERE privilege_code = 3 AND user_id = v_user_id
                 );
           END IF;
       END IF;

   FOR v_access_level IN SELECT unnest(ARRAY['READ', 'EDIT'])
LOOP
    IF (v_effective_mask & CASE v_access_level WHEN 'READ' THEN 1 WHEN 'EDIT' THEN 2 END) > 0 THEN

        -- Set privilege code and labels
        IF v_access_level = 'READ' THEN
            v_privilege_code := 1;
            v_label := 'Read';
            v_dev_name := 'read';
        ELSE
            v_privilege_code := 3;
            v_label := 'Edit Column';
            v_dev_name := 'edit_column';
        END IF;

        -- Fetch or create privilege_id
        SELECT privilege_id INTO v_privilege_id
        FROM production.privilege_meta
        WHERE privilege_code = v_privilege_code AND label = v_label AND user_id = v_user_id
        LIMIT 1;

        IF v_privilege_id IS NULL THEN
            INSERT INTO production.privilege_meta (
                label, developer_name, privilege_code, user_id, privilege_set_id
            ) VALUES (
                v_label, v_dev_name, v_privilege_code, v_user_id, v_privilege_set_id
            )
            RETURNING privilege_id INTO v_privilege_id;
        END IF;

        -- Assign to user if not already
        PERFORM 1 FROM production.user_privilege_assignment
        WHERE privilege_id = v_privilege_id AND user_id = v_user_id;

        IF NOT FOUND THEN
            INSERT INTO production.user_privilege_assignment (
                label, developer_name, privilege_id, user_id, created_by
            ) VALUES (
                CONCAT(v_label, ' - ', v_user_id),
                CONCAT(v_dev_name, '_', v_user_id),
                v_privilege_id, v_user_id, v_user_id
            ) ON CONFLICT DO NOTHING;
        END IF;

        -- Assign to column
        INSERT INTO production.column_privilege_meta (
            privilege_id, entity_id, column_id, access_level, created_by
        ) VALUES (
            v_privilege_id, v_entity_id, v_column_id, v_access_level, v_user_id
        )
        ON CONFLICT DO NOTHING;

        -- ✅ Append numeric codes
        IF v_privilege_code = 3 THEN
            -- Include implied READ (1)
            IF NOT 1 = ANY(v_new_privs) THEN
                v_new_privs := array_append(v_new_privs, 1);
            END IF;
        END IF;

        IF NOT v_privilege_code = ANY(v_new_privs) THEN
            v_new_privs := array_append(v_new_privs, v_privilege_code);
        END IF;
    END IF;
END LOOP;

   END LOOP;

   -- ✅ Delegate to assign_privilege_set_with_mappings to ensure consistency
 PERFORM production.assign_privilege_set_with_mappings(jsonb_build_object(
    'data_space', json_input->>'data_space',
    'active_session', json_input->'active_session',
    'data', jsonb_build_array(jsonb_build_object(
        'privilege_set_id', v_privilege_set_id,
        'user_id', v_user_id,
        'privilege_ids', COALESCE((
            SELECT jsonb_agg(privilege_id)
            FROM production.privilege_meta
            WHERE user_id = v_user_id AND privilege_code = ANY(v_new_privs)
        ), '[]'::jsonb)
    ))
));


  RETURN jsonb_build_object(
    'status', 'success',
    'user_id', v_user_id,
    'granted_access_levels', to_jsonb(
        ARRAY(
            SELECT DISTINCT p::text
            FROM unnest(v_new_privs) AS p
        )
    ),
    'bitmask_used', v_effective_mask
);

END;
$function$;
