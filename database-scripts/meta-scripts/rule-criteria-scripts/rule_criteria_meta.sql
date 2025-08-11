-----------------------------------------------------------------
--criteria_meta
-----------------------------------------------------------------
CREATE TABLE production."rule_criteria_meta" (
      rule_criteria_key serial NOT NULL,
      rule_criteria_id  varchar(22) GENERATED ALWAYS AS ('RCT' || LPAD(rule_criteria_key::TEXT, 19, '0')) STORED,
      sharing_rules_id  varchar(22) NOT NULL REFERENCES production."sharing_rules_meta"(sharing_rules_id) ON DELETE CASCADE,
      "label" VARCHAR(255) UNIQUE NOT NULL,
      developer_name VARCHAR(255) UNIQUE NOT NULL,
      operator VARCHAR(50) CHECK (operator IN (
                                               'equals', 'not equal to', 'starts with', 'contains', 'does not contain',
                                               'less than', 'greater than', 'less or equal', 'greater or equal',
                                               'includes', 'excludes', 'within')),
      "value" TEXT NOT NULL,
      "read" BOOLEAN DEFAULT FALSE CHECK ("read" IN (TRUE, FALSE)),
      read_and_write BOOLEAN DEFAULT FALSE CHECK (read_and_write IN (TRUE, FALSE)),
      additional_options BOOLEAN DEFAULT FALSE CHECK (additional_options IN (TRUE, FALSE)),
      created_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
      last_modified_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
      created_by  varchar(22),
      last_modified_by  varchar(22),
      version_number INTEGER DEFAULT 1,
      CONSTRAINT "pk_rule_criteria" PRIMARY KEY (rule_criteria_id)
);


-----------------------------------------------------------------
--criteria_meta
-----------------------------------------------------------------
CREATE INDEX idx_rule_criteria_meta_id ON production."rule_criteria_meta"(rule_criteria_id);
CREATE INDEX idx_rule_criteria_meta_label ON production."rule_criteria_meta"("label");
CREATE INDEX idx_rule_criteria_meta_developer_name ON production."rule_criteria_meta"(developer_name);
CREATE INDEX idx_rule_criteria_meta_created_date ON production."rule_criteria_meta"(created_date);
CREATE INDEX idx_rule_criteria_meta_last_modified_date ON production."rule_criteria_meta"(last_modified_date);
CREATE INDEX idx_rule_criteria_meta_created_by ON production."rule_criteria_meta"(created_by);
CREATE INDEX idx_rule_criteria_meta_last_modified_by ON production."rule_criteria_meta"(last_modified_by);


--Foreign Key For rule_criteria_meta
ALTER TABLE production."rule_criteria_meta"
ADD CONSTRAINT fk_rule_criteria_created_by FOREIGN KEY (created_by) REFERENCES production."user" (user_id) ON DELETE SET NULL;

ALTER TABLE production."rule_criteria_meta"
ADD CONSTRAINT fk_rule_criteria_last_modified_by FOREIGN KEY (last_modified_by) REFERENCES production."user" (user_id) ON DELETE SET NULL;
