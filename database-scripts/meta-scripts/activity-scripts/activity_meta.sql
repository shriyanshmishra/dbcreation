-----------------------------------------------------------------
--activity_meta
-----------------------------------------------------------------
CREATE TABLE production."activity_meta"(
        activity_key bigserial NOT NULL,
        activity_id  varchar(22) GENERATED ALWAYS AS ('ACT' || LPAD(activity_key::TEXT, 19, '0')) STORED,
        "label" VARCHAR(255) UNIQUE NOT NULL,
        developer_name VARCHAR(255) UNIQUE NOT NULL,
        subject VARCHAR(255) NOT NULL,
        description varchar(255),
        activity_type VARCHAR(100) NOT NULL,
        owner_id  varchar(22),
        related_to_type VARCHAR(100),
        related_to_id  varchar(22) REFERENCES production."entity_meta"(entity_id) ON DELETE SET NULL,
        created_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
        last_modified_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
        last_modified_by  varchar(22),
        created_by  varchar(22),
        version_number integer DEFAULT 1,
        CONSTRAINT "pk_activity_meta" PRIMARY KEY (activity_id)
);

-----------------------------------------------------------------
--activity_meta
-----------------------------------------------------------------
CREATE INDEX idx_activity_meta_id ON production."activity_meta"(activity_id);
CREATE INDEX idx_activity_meta_label ON production."activity_meta"("label");
CREATE INDEX idx_activity_meta_developer_name ON production."activity_meta"(developer_name);
CREATE INDEX idx_activity_meta_created_date ON production."activity_meta"(created_date);
CREATE INDEX idx_activity_meta_last_modified_date ON production."activity_meta"(last_modified_date);
CREATE INDEX idx_activity_meta_created_by ON production."activity_meta"(created_by);
CREATE INDEX idx_activity_meta_last_modified_by ON production."activity_meta"(last_modified_by);


--Foreign Key For activity_meta
ALTER TABLE production."activity_meta"
ADD CONSTRAINT fk_activity_created_by FOREIGN KEY (created_by) REFERENCES production."user" (user_id) ON DELETE SET NULL;

ALTER TABLE production."activity_meta"
ADD CONSTRAINT fk_activity_last_modified_by FOREIGN KEY (last_modified_by) REFERENCES production."user" (user_id) ON DELETE SET NULL;
