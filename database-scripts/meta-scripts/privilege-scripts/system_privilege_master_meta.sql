-----------------------------------------------------------------
--system_privilege_master
-----------------------------------------------------------------
CREATE TABLE production."system_privilege_master_meta"(
    system_privilege_master_key serial NOT NULL,
    system_privilege_master_id  varchar(22) GENERATED ALWAYS AS ('SPM' || LPAD(system_privilege_master_key::TEXT, 19, '0')) STORED,
    label varchar(1000) NULL,
    developer_name varchar(255) UNIQUE NOT NULL,
    description varchar(3000),
    created_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
    last_modified_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
    created_by varchar(22) NULL,
    last_modified_by varchar(22) NULL,
    version_number int4 DEFAULT 1 NULL,
    CONSTRAINT "pk_system_privilege_master" PRIMARY KEY (system_privilege_master_id)
);

-----------------------------------------------------------------
--system_privilege_master
-----------------------------------------------------------------

CREATE INDEX idx_system_privilege_master_id ON production."system_privilege_master_meta"(system_privilege_master_id);
CREATE INDEX idx_system_privilege_master_developer_name ON production."system_privilege_master_meta"(developer_name);
