-----------------------------------------------------------------
--owd_settings_meta
-----------------------------------------------------------------
CREATE TABLE production."owd_setting_meta" (
    owd_setting_meta_key SERIAL NOT NULL,
    owd_setting_meta_id  varchar(22) GENERATED ALWAYS AS ('OWD' || LPAD(owd_setting_meta_key::TEXT, 19, '0')) STORED,
    "label" VARCHAR(255) UNIQUE NOT NULL,
    developer_name VARCHAR(255) UNIQUE NOT NULL,
    entity_id  varchar(22) NOT NULL REFERENCES production."entity_meta"(entity_id) ON DELETE CASCADE,
    default_internal_access VARCHAR(50) CHECK (default_internal_access IN
        ('Private', 'Public Read Only', 'Public Read/Write', 'Public Read/Write/Transfer')),
    default_external_access VARCHAR(50) CHECK (default_external_access IN
        ('Private', 'Public Read Only', 'Public Read/Write', 'Public Read/Write/Transfer')),
    grant_access_using_hierarchies BOOLEAN DEFAULT FALSE CHECK (grant_access_using_hierarchies IN (TRUE, FALSE)),
    created_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
    last_modified_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
    last_modified_by  varchar(22),
    created_by  varchar(22),
    other_setting_id  varchar(22) DEFAULT 1 REFERENCES production."other_setting_meta"(other_setting_meta_id) ON DELETE CASCADE,
    version_number integer DEFAULT 1,
    CONSTRAINT "pk_owd_setting" PRIMARY KEY (owd_setting_meta_id)
);


-----------------------------------------------------------------
--owd_setting_meta
-----------------------------------------------------------------
CREATE INDEX idx_owd_setting_meta_id ON production."owd_setting_meta"(owd_setting_meta_id);
CREATE INDEX idx_owd_setting_meta_label ON production."owd_setting_meta"("label");
CREATE INDEX idx_owd_setting_meta_developer_name ON production."owd_setting_meta"(developer_name);
CREATE INDEX idx_owd_setting_meta_created_date ON production."owd_setting_meta"(created_date);
CREATE INDEX idx_owd_setting_meta_last_modified_date ON production."owd_setting_meta"(last_modified_date);
CREATE INDEX idx_owd_setting_meta_created_by ON production."owd_setting_meta"(created_by);
CREATE INDEX idx_owd_setting_meta_last_modified_by ON production."owd_setting_meta"(last_modified_by);


--Foreign Key For owd_setting_meta
ALTER TABLE production."owd_setting_meta"
ADD CONSTRAINT fk_owd_setting_created_by FOREIGN KEY (created_by) REFERENCES production."user" (user_id) ON DELETE SET NULL;

ALTER TABLE production."owd_setting_meta"
ADD CONSTRAINT fk_owd_setting_last_modified_by FOREIGN KEY (last_modified_by) REFERENCES production."user" (user_id) ON DELETE SET NULL;
