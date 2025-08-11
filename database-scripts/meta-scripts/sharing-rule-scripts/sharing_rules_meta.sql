
-----------------------------------------------------------------
--sharing_rule_meta
-----------------------------------------------------------------
CREATE TABLE production."sharing_rule_meta" (
      sharing_rule_key serial NOT NULL,
      sharing_rule_id  varchar(22) GENERATED ALWAYS AS ('SHR' || LPAD(sharing_rule_key::TEXT, 19, '0')) STORED,
      "label" VARCHAR(255) UNIQUE NOT NULL,
      developer_name VARCHAR(255) UNIQUE NOT NULL,
      rule_name VARCHAR(255) NOT NULL,
      rule_type VARCHAR(50) CHECK (rule_type IN ('Owner-Based', 'Criteria-Based', 'Manual')),
      public_group_id  varchar(22),
      role_id  varchar(22) REFERENCES production."role_meta"(role_id) ON DELETE SET NULL,
      created_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
      last_modified_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
      created_by  varchar(22),
      last_modified_by  varchar(22),
      version_number INTEGER DEFAULT 1,
      CONSTRAINT "pk_sharing_rule" PRIMARY KEY (sharing_rule_id)
);


-----------------------------------------------------------------
--sharing_rule_meta
-----------------------------------------------------------------
CREATE INDEX idx_sharing_rule_meta_id ON production."sharing_rule_meta"(sharing_rule_id);
CREATE INDEX idx_sharing_rule_meta_label ON production."sharing_rule_meta"("label");
CREATE INDEX idx_sharing_rule_meta_developer_name ON production."sharing_rule_meta"(developer_name);
CREATE INDEX idx_sharing_rule_meta_created_date ON production."sharing_rule_meta"(created_date);
CREATE INDEX idx_sharing_rule_meta_last_modified_date ON production."sharing_rule_meta"(last_modified_date);
CREATE INDEX idx_sharing_rule_meta_created_by ON production."sharing_rule_meta"(created_by);
CREATE INDEX idx_sharing_rule_meta_last_modified_by ON production."sharing_rule_meta"(last_modified_by);

--Foreign Key For sharing_rule_meta
ALTER TABLE production."sharing_rule_meta"
ADD CONSTRAINT fk_sharing_rule_public_group_id FOREIGN KEY (public_group_id) REFERENCES production."public_group_meta" (public_group_id) ON DELETE SET NULL;

ALTER TABLE production."sharing_rule_meta"
ADD CONSTRAINT fk_sharing_rule_created_by FOREIGN KEY (created_by) REFERENCES production."user" (user_id) ON DELETE SET NULL;

ALTER TABLE production."sharing_rule_meta"
ADD CONSTRAINT fk_sharing_rule_last_modified_by FOREIGN KEY (last_modified_by) REFERENCES production."user" (user_id) ON DELETE SET NULL;
