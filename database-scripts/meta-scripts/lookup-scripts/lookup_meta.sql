-----------------------------------------------------------------
--lookup_meta
-----------------------------------------------------------------
CREATE TABLE production."lookup_meta"(
      lookup_key serial NOT NULL,
      lookup_id  varchar(22) GENERATED ALWAYS AS ('LKP' || LPAD(lookup_key::TEXT, 19, '0')) STORED,
      entity_id  varchar(22) NOT NULL REFERENCES production."entity_meta"(entity_id) ON DELETE CASCADE,
      column_id  varchar(22) NOT NULL REFERENCES production."column_meta"(column_id) ON DELETE CASCADE,
      entity_prefix VARCHAR(3) NOT NULL,
      parent_id  varchar(22) ,                           --related to which entity_id
      created_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
      last_modified_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
      last_modified_by  varchar(22),
      created_by  varchar(22),
      "description" varchar(2000) NULL,
      version_number integer DEFAULT 1,
      CONSTRAINT "pk_lookup" PRIMARY KEY (lookup_id)
);

-----------------------------------------------------------------
--lookup_meta
-----------------------------------------------------------------

CREATE INDEX idx_lookup_meta_id ON production."lookup_meta"(lookup_id);
CREATE INDEX idx_lookup_meta_created_date ON production."lookup_meta"(created_date);
CREATE INDEX idx_lookup_meta_last_modified_date ON production."lookup_meta"(last_modified_date);
CREATE INDEX idx_lookup_meta_created_by ON production."lookup_meta"(created_by);
CREATE INDEX idx_lookup_meta_last_modified_by ON production."lookup_meta"(last_modified_by);

--Foreign Key For lookup_meta
ALTER TABLE production."lookup_meta"
ADD CONSTRAINT fk_lookup_created_by FOREIGN KEY (created_by) REFERENCES production."user" (user_id) ON DELETE SET NULL;

ALTER TABLE production."lookup_meta"
ADD CONSTRAINT fk_lookup_last_modified_by FOREIGN KEY (last_modified_by) REFERENCES production."user" (user_id) ON DELETE SET NULL;
