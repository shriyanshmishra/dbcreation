CREATE OR REPLACE FUNCTION production.check_permission_function(current_user_id text, current_entity_id text, current_column_id text)
RETURNS BOOLEAN 
LANGUAGE plpgsql
AS $$
DECLARE
    permissions jsonb;
    entity_permission jsonb;
    column_permission jsonb;
    entity_access_level INT;
    column_access_level INT;

    -- Permission Constants
    READ         CONSTANT INT := 1;
    WRITE        CONSTANT INT := 2;
    EDIT         CONSTANT INT := 4;
    DELETE       CONSTANT INT := 8;
    VIEW_ALL     CONSTANT INT := 16;
    MODIFY_ALL   CONSTANT INT := 32;
BEGIN
    -- Fetch user permission JSON
    SELECT user_permissions INTO permissions
    FROM production.user_access_json_view
    WHERE user_id = current_user_id;

    -- Loop through entity_permissions
    FOR entity_permission IN 
        SELECT * FROM jsonb_array_elements(permissions->'entity_permissions')
    LOOP
        IF entity_permission->>'entity_id' = current_entity_id THEN
            entity_access_level := (entity_permission->>'access_level')::int;

            -- Check for entity write/edit/delete permission
            IF (entity_access_level & WRITE) = WRITE OR ((entity_access_level # EDIT) & EDIT) = 0 OR ((entity_access_level # DELETE) & DELETE) = 0 OR ((entity_access_level # MODIFY_ALL) & MODIFY_ALL) = 0 THEN
                RAISE NOTICE 'User has WRITE permission for entity: %', current_entity_id;

                -- Loop through column permissions
                FOR column_permission IN 
                    SELECT * FROM jsonb_array_elements(permissions->'column_permissions')
                LOOP
                    IF column_permission->>'column_id' = current_column_id AND entity_permission->>'entity_id' = current_entity_id THEN
                        column_access_level := (column_permission->>'access_level')::int;
                        IF (column_access_level & WRITE) = WRITE THEN
                            RAISE NOTICE 'User has WRITE permission for column: %', current_column_id;
                            RETURN TRUE;
                        ELSE
                            RETURN FALSE;
                        END IF;
                    END IF;
                END LOOP;
            ELSE
                RAISE NOTICE 'User does NOT have WRITE permission for entity: %', current_entity_id;
            END IF;

            -- For Edit Access
            IF ((user_perm # EDIT) & EDIT) = 0 OR ((user_perm # DELETE) & DELETE) = 0 OR ((user_perm # MODIFY_ALL) & MODIFY_ALL) = 0 THEN
                RAISE NOTICE 'User has EDIT permission for entity: %', 'ENT0000000000000000031';
				RAISE NOTICE '2nd if else Part';
                FOR column_permission IN 
                    SELECT * FROM jsonb_array_elements(permissions->'column_permissions')
                LOOP
                    IF column_permission->>'column_id' = current_column_id AND entity_permission->>'entity_id' = current_entity_id THEN
                        column_access_level := (column_permission->>'access_level')::int;
                        IF (column_access_level & EDIT) = EDIT THEN
                            RAISE NOTICE 'User has WRITE permission for column: %', current_column_id;
                            RETURN TRUE;
                        ELSE
                            RETURN FALSE;
                        END IF;
                    END IF;
                END LOOP;
            ELSE
                RAISE NOTICE 'User does NOT have Update permission for entity : % & column : %', current_entity_id, current_column_id;
            END IF;
        END IF;
    END LOOP;
    RETURN FALSE; -- No matching permission found
END;
$$;