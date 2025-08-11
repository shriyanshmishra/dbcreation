-----------------------------------------------------------------
--other_setting_meta
-----------------------------------------------------------------
CREATE TABLE production."other_setting_meta" (
        other_setting_key SERIAL NOT NULL,
        other_setting_meta_id  varchar(22) GENERATED ALWAYS AS ('OST' || LPAD(other_setting_key::TEXT, 19, '0')) STORED,
        "label" VARCHAR(255) UNIQUE NOT NULL,
        developer_name VARCHAR(255) UNIQUE NOT NULL,
        manager_groups BOOLEAN DEFAULT FALSE CHECK (manager_groups IN (TRUE, FALSE)),
        minimize_roles BOOLEAN DEFAULT FALSE CHECK (minimize_roles IN (TRUE, FALSE)),
        grant_site_users_case_access BOOLEAN DEFAULT FALSE CHECK (grant_site_users_case_access IN (TRUE, FALSE)),
        require_permission_for_lookup BOOLEAN DEFAULT FALSE CHECK (require_permission_for_lookup IN (TRUE, FALSE)),
        created_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
        last_modified_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
        last_modified_by  varchar(22),
        created_by  varchar(22),

        version_number integer DEFAULT 1,
        CONSTRAINT "pk_other_setting_meta" PRIMARY KEY (other_setting_meta_id)
);


-----------------------------------------------------------------
--other_setting_meta
-----------------------------------------------------------------
CREATE INDEX idx_other_setting_meta_id ON production."other_setting_meta"(other_setting_meta_id);
CREATE INDEX idx_other_setting_meta_label ON production."other_setting_meta"("label");
CREATE INDEX idx_other_setting_meta_developer_name ON production."other_setting_meta"(developer_name);
CREATE INDEX idx_other_setting_meta_created_date ON production."other_setting_meta"(created_date);
CREATE INDEX idx_other_setting_meta_last_modified_date ON production."other_setting_meta"(last_modified_date);
CREATE INDEX idx_other_setting_meta_created_by ON production."other_setting_meta"(created_by);
CREATE INDEX idx_other_setting_meta_last_modified_by ON production."other_setting_meta"(last_modified_by);

--Foreign Key For other_setting_meta
ALTER TABLE production."other_setting_meta"
ADD CONSTRAINT fk_other_setting_created_by FOREIGN KEY (created_by) REFERENCES production."user" (user_id) ON DELETE SET NULL;

ALTER TABLE production."other_setting_meta"
ADD CONSTRAINT fk_other_setting_last_modified_by FOREIGN KEY (last_modified_by) REFERENCES production."user" (user_id) ON DELETE SET NULL;
