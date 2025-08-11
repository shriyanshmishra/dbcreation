-----------------------------------------------------------------
--roles_meta
-----------------------------------------------------------------
CREATE TABLE production."role_meta"(
        role_key serial NOT NULL,
        role_id  varchar(22) GENERATED ALWAYS AS ('ROL' || LPAD(role_key::TEXT, 19, '0')) STORED,
        "label" varchar(255) UNIQUE NOT NULL,
        developer_name VARCHAR(255) UNIQUE NOT NULL,
        reports_to  varchar(22) REFERENCES production."role_meta"(role_id) ON DELETE SET NULL,
        access_only_own_opportunity_records BOOLEAN DEFAULT FALSE CHECK (access_only_own_opportunity_records IN (TRUE, FALSE)),
        view_all_opportunity_records_related_to_account BOOLEAN DEFAULT FALSE CHECK (view_all_opportunity_records_related_to_account IN (TRUE, FALSE)),
        modify_all_opportunity_records_related_to_account BOOLEAN DEFAULT FALSE CHECK (modify_all_opportunity_records_related_to_account IN (TRUE, FALSE)),
        created_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
        last_modified_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
        last_modified_by  varchar(22),
        created_by  varchar(22),
        version_number integer DEFAULT 1,
        CONSTRAINT "pk_role_meta" PRIMARY KEY (role_id)
);


-----------------------------------------------------------------
--roles_meta
-----------------------------------------------------------------
CREATE INDEX idx_role_meta_id ON production."role_meta"(role_id);
CREATE INDEX idx_role_meta_label ON production."role_meta"("label");
CREATE INDEX idx_role_meta_developer_name ON production."role_meta"(developer_name);
CREATE INDEX idx_role_meta_created_date ON production."role_meta"(created_date);
CREATE INDEX idx_role_meta_last_modified_date ON production."role_meta"(last_modified_date);
CREATE INDEX idx_role_meta_created_by ON production."role_meta"(created_by);
CREATE INDEX idx_role_meta_last_modified_by ON production."role_meta"(last_modified_by);


--Foreign Key For role_meta
ALTER TABLE production."role_meta"
ADD CONSTRAINT fk_role_created_by FOREIGN KEY (created_by) REFERENCES production."user" (user_id) ON DELETE SET NULL;

ALTER TABLE production."role_meta"
ADD CONSTRAINT fk_role_last_modified_by FOREIGN KEY (last_modified_by) REFERENCES production."user" (user_id) ON DELETE SET NULL;
