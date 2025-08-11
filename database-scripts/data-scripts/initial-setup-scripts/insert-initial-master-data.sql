CREATE OR REPLACE FUNCTION production.insert_initial_master_data()
RETURNS VOID AS $$
DECLARE
    first_user_id VARCHAR(22);
    system_admin_privilege_id VARCHAR(22);
    masterRecord RECORD;
BEGIN
    -- Step 1
    SELECT user_id INTO first_user_id
    FROM production.user
    ORDER BY created_date ASC NULLS LAST
    LIMIT 1;

    IF first_user_id IS NULL THEN
        RAISE EXCEPTION 'No users found in production.user table.';
    END IF;

    -- Step 2 - Idempotent insert
    INSERT INTO production.system_privilege_master_meta (developer_name, label, created_by, last_modified_by)
    VALUES
    ('access_setup_menu', 'Setup menu access', first_user_id, first_user_id),
    ('mass_email', 'Send mass emails', first_user_id, first_user_id),
    ('send_email', 'Send email', first_user_id, first_user_id),
    ('edit_html_templates', 'Edit email template', first_user_id, first_user_id),
    ('view_roles_and_roles_hierarchy', 'View roles and role hierarchy', first_user_id, first_user_id)
    ON CONFLICT (developer_name) DO NOTHING;

    -- Step 3
    system_admin_privilege_id := production.__create_system_admin_privilege_if_not_exists(first_user_id);

    -- Step 4
    FOR masterRecord IN
        SELECT system_privilege_master_id FROM production.system_privilege_master_meta
    LOOP
        INSERT INTO production.system_privilege_meta(
            privilege_id,
            system_privilege_master_id,
            "type",
            created_by,
            last_modified_by
        )
        VALUES (
            system_admin_privilege_id,
            masterRecord.system_privilege_master_id,
            'true',
            first_user_id,
            first_user_id
        );
    END LOOP;

    -- Step 5
    INSERT INTO production.user_privilege_assignment (
        label,
        developer_name,
        privilege_id,
        user_id
    )
    VALUES (
       'Assigning System Privilege',
       'assigning_system_privilege',
       system_admin_privilege_id,
       first_user_id
   )
    ON CONFLICT DO NOTHING;

    -- Step 6
    PERFORM production.__insert_default_response_codes_if_not_exist(first_user_id);
END;
$$ LANGUAGE plpgsql;