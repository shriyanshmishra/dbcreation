CREATE OR REPLACE FUNCTION production.__create_system_admin_privilege_if_not_exists(
    created_by_user_id VARCHAR(22)
)
RETURNS VARCHAR(22) AS $$
DECLARE
    system_admin_privilege_id VARCHAR(22);
BEGIN
    -- Check if already exists
    SELECT privilege_id INTO system_admin_privilege_id
    FROM production.privilege_meta
    WHERE developer_name = 'system_administrator'
    LIMIT 1;

    -- Insert if not exists
    IF system_admin_privilege_id IS NULL THEN
        INSERT INTO production.privilege_meta (
            label,
            developer_name,
            session_activation_required,
            description,
            created_by,
            last_modified_by
        )
        VALUES (
            'System Administrator',
            'system_administrator',
            FALSE,
            'Full system access including settings',
            created_by_user_id,
            created_by_user_id
        )
    RETURNING privilege_id INTO system_admin_privilege_id;
END IF;

RETURN system_admin_privilege_id;
END;
$$ LANGUAGE plpgsql;