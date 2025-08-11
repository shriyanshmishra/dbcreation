-----------------------------------------------------------------
-- privilege_set_mapping
-----------------------------------------------------------------
CREATE TABLE production."privilege_set_mapping_meta" (
    privilege_set_mapping_meta_key serial NOT NULL,
    privilege_set_id varchar(22) NOT NULL,
    privilege_id varchar(22) NOT NULL,
    created_by varchar(22),
    description varchar(255) NULL,
    created_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
    last_modified_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
    last_modified_by varchar(22) NULL,
    created_by varchar(22) NULL,
    version_number int4 DEFAULT 1 NULL,

    CONSTRAINT privilege_set_mapping_meta_pkey PRIMARY KEY (privilege_set_mapping_meta_key),
    CONSTRAINT uq_set_privilege UNIQUE (privilege_set_id, privilege_id)
);

-----------------------------------------------------------------
-- Indexes for privilege_set_mapping_meta
-----------------------------------------------------------------
CREATE INDEX idx_psm_privilege_set_id ON production."privilege_set_mapping_meta"(privilege_set_id);
CREATE INDEX idx_psm_privilege_id ON production."privilege_set_mapping_meta"(privilege_id);
CREATE INDEX idx_psm_created_by ON production."privilege_set_mapping_meta"(created_by);
CREATE INDEX idx_psm_created_date ON production."privilege_set_mapping_meta"(created_date);

-----------------------------------------------------------------
-- Foreign Keys for privilege_set_mapping_meta
-----------------------------------------------------------------
ALTER TABLE production."privilege_set_mapping_meta"
ADD CONSTRAINT fk_psm_set FOREIGN KEY (privilege_set_id)
REFERENCES production."privilege_set_meta"(privilege_set_id) ON DELETE CASCADE;

ALTER TABLE production."privilege_set_mapping_meta"
ADD CONSTRAINT fk_psm_privilege FOREIGN KEY (privilege_id)
REFERENCES production."privilege_meta"(privilege_id) ON DELETE CASCADE;

ALTER TABLE production."privilege_set_mapping_meta"
ADD CONSTRAINT fk_psm_created_by FOREIGN KEY (created_by)
REFERENCES production."user"(user_id) ON DELETE SET NULL;
