
-----------------------------------------------------------------
--column_privilege_meta
-----------------------------------------------------------------
CREATE TABLE production."column_privilege_meta"(
    column_privilege_key serial NOT NULL,
    column_privilege_id  varchar(22) GENERATED ALWAYS AS ('CPL' || LPAD(column_privilege_key::TEXT, 19, '0')) STORED,
    privilege_id  varchar(22) NOT NULL REFERENCES production."privilege_meta"(privilege_id) ON DELETE CASCADE,
    entity_id varchar(22) NOT NULL REFERENCES production."entity_meta"(entity_id) ON DELETE CASCADE,
    column_id varchar(22) NOT NULL REFERENCES production."column_meta"(column_id) ON DELETE CASCADE,
    access_level varchar(255) NOT NULL,
    created_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
    last_modified_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
    last_modified_by  varchar(22),
    created_by  varchar(22),
    version_number integer DEFAULT 1,
    CONSTRAINT "pk_column_privilege_meta" PRIMARY KEY (column_privilege_id)
);


-----------------------------------------------------------------
--column_privilege_meta
-----------------------------------------------------------------
CREATE INDEX idx_column_privilege_meta_id ON production."column_privilege_meta"(column_privilege_id);
CREATE INDEX idx_column_privilege_meta_access_level ON production."column_privilege_meta"(access_level);
CREATE INDEX idx_column_privilege_meta_created_date ON production."column_privilege_meta"(created_date);
CREATE INDEX idx_column_privilege_meta_last_modified ON production."column_privilege_meta"(last_modified_date);
CREATE INDEX idx_column_privilege_meta_created_by ON production."column_privilege_meta"(created_by);
CREATE INDEX idx_column_privilege_meta_last_modified_by ON production."column_privilege_meta"(last_modified_by);


--Foreign Key For column_privilege_meta
ALTER TABLE production."column_privilege_meta"
ADD CONSTRAINT fk_column_privilege_created_by FOREIGN KEY (created_by) REFERENCES production."user" (user_id) ON DELETE SET NULL;

ALTER TABLE production."column_privilege_meta"
ADD CONSTRAINT fk_column_privilege_last_modified_by FOREIGN KEY (last_modified_by) REFERENCES production."user" (user_id) ON DELETE SET NULL;
