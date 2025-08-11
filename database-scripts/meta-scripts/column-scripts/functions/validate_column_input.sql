-- DROP FUNCTION production.validate_column_input(jsonb);

CREATE OR REPLACE FUNCTION production.validate_column_input(json_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    item jsonb;
    error_data jsonb := '[]'::jsonb;
    v_entity_id TEXT;
    entity_exists BOOLEAN;
    v_precision INT;
    v_decimal_places INT;
    picklist_item jsonb;
    seen_values TEXT[];
    v_val TEXT;
    current_user_id TEXT;
BEGIN
    -- Step 1: Ensure required keys exist
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

    -- Step 2: Ensure "data" is an array
    IF jsonb_typeof(json_input->'data') <> 'array' THEN
        RETURN production.get_response_message(
            jsonb_build_object(
                'data', jsonb_build_array(jsonb_build_object('error_code', '1002')),
                'active_session', json_input->'active_session'
            )
        );
    END IF;

    -- Step 3: Validate session_token and get user_id
    SELECT user_id INTO current_user_id
    FROM production.login_session_meta
    WHERE session_token = json_input->'active_session'->>'session_token';

    IF current_user_id IS NULL THEN
        RETURN production.get_response_message(
            jsonb_build_object(
                'data', jsonb_build_array(jsonb_build_object('error_code', '1003')),
                'active_session', json_input->'active_session'
            )
        );
    END IF;

    -- Step 4: Check if schema (data_space) exists
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

    -- Step 5: Validate each column definition
    FOR item IN SELECT * FROM jsonb_array_elements(json_input->'data')
    LOOP
        v_entity_id := item->>'entity_id';

        IF v_entity_id IS NULL OR trim(v_entity_id) = '' THEN
            RETURN production.get_response_message(
                jsonb_build_object('data', jsonb_build_array(jsonb_build_object('error_code', '1006')))
            );
        END IF;

        SELECT EXISTS (
            SELECT 1 FROM production.entity_meta WHERE entity_id = v_entity_id
        ) INTO entity_exists;

        IF NOT entity_exists THEN
            RETURN production.get_response_message(
                jsonb_build_object('data', jsonb_build_array(jsonb_build_object('error_code', '1006')))
            );
        END IF;

        IF item->>'developer_name' IS NULL OR trim(item->>'developer_name') = '' THEN
            RETURN production.get_response_message(
                jsonb_build_object('data', jsonb_build_array(jsonb_build_object('error_code', '1107')))
            );
        END IF;

        IF item->>'label' IS NULL OR trim(item->>'label') = '' THEN
            RETURN production.get_response_message(
                jsonb_build_object('data', jsonb_build_array(jsonb_build_object('error_code', '1108')))
            );
        END IF;

        IF item->>'data_type' = 'None Selected' THEN
            RETURN production.get_response_message(
                jsonb_build_object('data', jsonb_build_array(jsonb_build_object('error_code', '1109')))
            );
        END IF;

        IF item->>'data_type' = 'lookup' AND (item->>'parent_entity_id') IS NULL THEN
            RETURN production.get_response_message(
                jsonb_build_object('data', jsonb_build_array(jsonb_build_object('error_code', '1103')))
            );
        END IF;

        IF item->>'data_type' = 'master' AND item->>'parent_entity_id' = v_entity_id THEN
            RETURN production.get_response_message(
                jsonb_build_object('data', jsonb_build_array(jsonb_build_object('error_code', '1105')))
            );
        END IF;

        IF item->>'data_type' = 'master' AND (item->>'parent_entity_id') IS NULL OR trim(item->>'parent_entity_id') = '' THEN
            RETURN production.get_response_message(
                jsonb_build_object('data', jsonb_build_array(jsonb_build_object('error_code', '1104')))
            );
        END IF;

        IF EXISTS (
            SELECT 1 FROM production.column_meta
            WHERE entity_id = v_entity_id AND developer_name = item->>'developer_name'
        ) THEN
            RETURN production.get_response_message(
                jsonb_build_object('data', jsonb_build_array(jsonb_build_object('error_code', '1106')))
            );
        END IF;

        IF item->>'data_type' IN ('number', 'currency', 'percent') THEN
            v_precision := COALESCE((item->>'integer')::int, 0);
            v_decimal_places := COALESCE((item->>'decimal')::int, 0);

            IF (v_precision + v_decimal_places) > 18 THEN
                RETURN production.get_response_message(
                    jsonb_build_object('data', jsonb_build_array(jsonb_build_object('error_code', '1110')))
                );
            END IF;
        END IF;

        IF item->>'data_type' IN ('picklist', 'multi_picklist') THEN
            IF jsonb_typeof(item->'picklist_values') = 'array' THEN
                seen_values := ARRAY[]::TEXT[];

                FOR picklist_item IN SELECT * FROM jsonb_array_elements(item->'picklist_values')
                LOOP
                    v_val := trim(picklist_item->>'value');

                    IF v_val IS NULL OR v_val = '' THEN
                        RETURN production.get_response_message(
                            jsonb_build_object('data', jsonb_build_array(jsonb_build_object('error_code', '1111')))
                        );
                    END IF;

                    IF v_val = ANY(seen_values) THEN
                        RETURN production.get_response_message(
                            jsonb_build_object('data', jsonb_build_array(jsonb_build_object('error_code', '1112')))
                        );
                    END IF;

                    seen_values := array_append(seen_values, v_val);
                END LOOP;
            END IF;
        END IF;
    END LOOP;

    RETURN production.get_response_message(
        jsonb_build_object(
            'data', jsonb_build_array(jsonb_build_object('response_code', '2008')),
            'active_session', json_input->'active_session'
        ));-- All validations passed
END;
$function$
;
