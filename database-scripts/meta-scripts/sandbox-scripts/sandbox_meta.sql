-----------------------------------------------------------------
--sandbox_meta
-----------------------------------------------------------------
CREATE TABLE production."sandbox_meta"(
       sandbox_key serial NOT NULL,
       sandbox_id  varchar(22) GENERATED ALWAYS AS ('SBX' || LPAD(sandbox_key::TEXT, 19, '0')) STORED,
       "label" varchar(255) UNIQUE NOT NULL,
       developer_name VARCHAR(255) UNIQUE NOT NULL,
       description varchar(255),
       sandbox_license varchar(255),
       status VARCHAR(50),
       "location" VARCHAR(255),
       release_type VARCHAR(50),
       current_org_id VARCHAR(255),
       completed_on TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
       last_refresh_request_by  varchar(22),
       last_refresh_request_date  varchar(22),
       refresh_interval VARCHAR(16),
       next_refresh_available VARCHAR(16),
       auto_active BOOLEAN DEFAULT FALSE CHECK (auto_active IN (TRUE, FALSE)),
       on_demand_refresh BOOLEAN DEFAULT FALSE CHECK (on_demand_refresh IN (TRUE, FALSE)),
       created_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
       last_modified_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
       last_modified_by  varchar(22),
       created_by  varchar(22),
       version_number integer DEFAULT 1,
       CONSTRAINT "pk_sandbox" PRIMARY KEY (sandbox_id)
);


-----------------------------------------------------------------
--sandbox_meta
-----------------------------------------------------------------

CREATE INDEX idx_sandbox_meta_id ON production."sandbox_meta"(sandbox_id);
CREATE INDEX idx_sandbox_meta_label ON production."sandbox_meta"("label");
CREATE INDEX idx_sandbox_meta_developer_name ON production."sandbox_meta"(developer_name);
CREATE INDEX idx_sandbox_meta_created_date ON production."sandbox_meta"(created_date);
CREATE INDEX idx_sandbox_meta_last_modified_date ON production."sandbox_meta"(last_modified_date);
CREATE INDEX idx_sandbox_meta_created_by ON production."sandbox_meta"(created_by);
CREATE INDEX idx_sandbox_meta_last_modified_by ON production."sandbox_meta"(last_modified_by);


--Foreign Key For sandbox_meta
ALTER TABLE production."sandbox_meta"
ADD CONSTRAINT fk_sandbox_created_by FOREIGN KEY (created_by) REFERENCES production."user" (user_id) ON DELETE SET NULL;

ALTER TABLE production."sandbox_meta"
ADD CONSTRAINT fk_sandbox_last_modified_by FOREIGN KEY (last_modified_by) REFERENCES production."user" (user_id) ON DELETE SET NULL;
