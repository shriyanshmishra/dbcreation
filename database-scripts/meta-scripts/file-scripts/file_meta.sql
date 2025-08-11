-----------------------------------------------------------------
--file_meta
-----------------------------------------------------------------
CREATE TABLE production."file_meta"(
    file_key serial NOT NULL,
    file_id varchar(22) GENERATED ALWAYS AS ('FIL' || LPAD(file_key::TEXT, 19, '0')) STORED,
    "label" varchar(255) UNIQUE NOT NULL,
    developer_name VARCHAR(255) UNIQUE NOT NULL,
    file_type VARCHAR(100) NOT NULL,
    file_size BIGINT CHECK (file_size >= 0),
    related_record_id varchar(22),
    entity_id varchar(22) NOT NULL REFERENCES production."entity_meta"(entity_id) ON DELETE CASCADE,
    blob_data OID NOT NULL,
    created_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
    last_modified_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
    last_modified_by varchar(22),
    created_by varchar(22),
    version_number integer DEFAULT 1,
    CONSTRAINT "pk_file" PRIMARY KEY (file_id)
);

-----------------------------------------------------------------
--file_meta
-----------------------------------------------------------------
CREATE INDEX idx_file_id ON production."file_meta"(file_id);
CREATE INDEX idx_file_label ON production."file_meta"("label");
CREATE INDEX idx_file_developer_name ON production."file_meta"(developer_name);
CREATE INDEX idx_file_created_date ON production."file_meta"(created_date);
CREATE INDEX idx_file_last_modified_date ON production."file_meta"(last_modified_date);
CREATE INDEX idx_file_created_by ON production."file_meta"(created_by);
CREATE INDEX idx_file_last_modified_by ON production."file_meta"(last_modified_by);

--Foreign Key For file_meta
ALTER TABLE production."file_meta"
ADD CONSTRAINT fk_file_meta_created_by FOREIGN KEY (created_by) REFERENCES production."user" (user_id) ON DELETE SET NULL;

ALTER TABLE production."file_meta"
ADD CONSTRAINT fk_file_meta_last_modified_by FOREIGN KEY (last_modified_by) REFERENCES production."user" (user_id) ON DELETE SET NULL;
