----------------------------------------------------------------
--creating view for user_privilege_json_view
----------------------------------------------------------------
CREATE OR REPLACE VIEW production.user_access_json_view AS
SELECT
    u.user_id,
    jsonb_build_object(
            'system_permissions', (
            SELECT jsonb_agg(jsonb_build_object(
                    'privilege_id', p.privilege_id,
                    'system_privilege_id', sp.system_privilege_id,
                    ' flag', sp.flag
                             ))
            FROM production.user_privilege_assignment upa
                     JOIN production.privilege_meta p ON p.privilege_id = upa.privilege_id
                     JOIN production.system_privilege_meta sp ON sp.privilege_id = p.privilege_id
            WHERE upa.user_id = u.user_id
        ),
        'entity_permissions', (
            SELECT jsonb_agg(jsonb_build_object(
                    'privilege_id', p.privilege_id,
                    'entity_id', em.entity_id,
                    'entity_developer_name', em.developer_name,
                    'access_level', ep.access_level
                 ))
            FROM production.user_privilege_assignment upa
                     JOIN production.privilege_meta p ON p.privilege_id = upa.privilege_id
                     JOIN production.entity_privilege_meta ep ON ep.privilege_id = p.privilege_id
                     JOIN production.entity_meta em ON em.entity_id = ep.entity_id
            WHERE upa.user_id = u.user_id
        ),

        'column_permissions', (
            SELECT jsonb_agg(jsonb_build_object(
                    'privilege_id', p.privilege_id,
                    'entity_id', em.entity_id,
                    'entity_developer_name', em.developer_name,
                    'column_id', cm.column_id,
                    'column_developer_name', cm.developer_name,
                    'access_level', cp.access_level
            ))
            FROM production.user_privilege_assignment upa
                     JOIN production.privilege_meta p ON p.privilege_id = upa.privilege_id
                     JOIN production.column_privilege_meta cp ON cp.privilege_id = p.privilege_id
                     JOIN production.column_meta cm ON cm.column_id = cp.column_id
                     JOIN production.entity_meta em ON em.entity_id = cp.entity_id
            WHERE upa.user_id = u.user_id
        )
    ) AS user_permissions
FROM production."user" u;