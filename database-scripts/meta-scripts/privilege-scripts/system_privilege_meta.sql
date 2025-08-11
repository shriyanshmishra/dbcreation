-----------------------------------------------------------------
-- system_privilege_meta
-----------------------------------------------------------------
CREATE TABLE production."system_privilege_meta" (
    system_privilege_key serial NOT NULL,
    system_privilege_id varchar(22) GENERATED ALWAYS AS ('SPL' || LPAD(system_privilege_key::TEXT, 19, '0')) STORED,
    privilege_id varchar(22) NOT NULL,
    system_privilege_master_id varchar(22) NOT NULL,
    created_date timestamptz DEFAULT CURRENT_TIMESTAMP,
    last_modified_date timestamptz DEFAULT CURRENT_TIMESTAMP,
    last_modified_by varchar(22),
    created_by varchar(22),
    version_number integer DEFAULT 1,
    is_enabled boolean DEFAULT true,
    flag boolean,

    CONSTRAINT pk_system_privilege PRIMARY KEY (system_privilege_id)
);

-----------------------------------------------------------------
--system_privilege_meta
-----------------------------------------------------------------
CREATE INDEX idx_system_privilege_meta_id ON production."system_privilege_meta"(system_privilege_id);
CREATE INDEX idx_system_privilege_meta_created_by ON production."system_privilege_meta"(created_by);
CREATE INDEX idx_system_privilege_meta_last_modified_by ON production."system_privilege_meta"(last_modified_by);
CREATE INDEX idx_system_privilege_meta_created_date ON production."system_privilege_meta"(created_date);
CREATE INDEX idx_system_privilege_meta_last_modified_date ON production."system_privilege_meta"(last_modified_date);

-----------------------------------------------------------------
-- Foreign Keys for system_privilege_meta
-----------------------------------------------------------------
ALTER TABLE production."system_privilege_meta"
ADD CONSTRAINT fk_system_privilege_created_by FOREIGN KEY (created_by)
REFERENCES production."user"(user_id) ON DELETE SET NULL;

ALTER TABLE production."system_privilege_meta"
ADD CONSTRAINT fk_system_privilege_last_modified_by FOREIGN KEY (last_modified_by)
REFERENCES production."user"(user_id) ON DELETE SET NULL;

ALTER TABLE production."system_privilege_meta"
ADD CONSTRAINT system_privilege_meta_privilege_id_fkey FOREIGN KEY (privilege_id)
REFERENCES production."privilege_meta"(privilege_id) ON DELETE CASCADE;

ALTER TABLE production."system_privilege_meta"
ADD CONSTRAINT system_privilege_meta_system_privilege_master_id_fkey FOREIGN KEY (system_privilege_master_id)
REFERENCES production."system_privilege_master_meta"(system_privilege_master_id) ON DELETE CASCADE;
