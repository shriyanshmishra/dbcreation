-----------------------------------------------------------------
--column_meta
-----------------------------------------------------------------
CREATE TABLE production."column_meta"(
      column_key bigserial NOT NULL,
      column_id  varchar(22) GENERATED ALWAYS AS ('COL' || LPAD(column_key::TEXT, 19, '0')) STORED,
      "label" VARCHAR(255)  NOT NULL,
      entity_id  varchar(22) NOT NULL REFERENCES production."entity_meta"(entity_id) ON DELETE CASCADE,
      developer_name VARCHAR(255) NOT NULL,
      data_type VARCHAR(100) NOT NULL,
      "description" varchar(2000),
      "length" INT,
      integer INT,
      decimal DECIMAL(18,6),
      latitude DOUBLE PRECISION,
      longitude DOUBLE PRECISION,
      boolean_value BOOLEAN DEFAULT FALSE CHECK (boolean_value IN (TRUE, FALSE)),
      required BOOLEAN DEFAULT FALSE CHECK (required IN (TRUE, FALSE)),
      "unique" BOOLEAN DEFAULT FALSE CHECK ("unique" IN (TRUE, FALSE)),
      picklist BOOLEAN DEFAULT FALSE CHECK (picklist IN (TRUE, FALSE)),
      multi_picklist BOOLEAN DEFAULT FALSE CHECK (multi_picklist IN (TRUE, FALSE)),
      pg_data_type varchar(100) not null,
      if_delete_clean_values BOOLEAN DEFAULT FALSE CHECK (if_delete_clean_values IN (TRUE, FALSE)),
      do_not_allow_deletion BOOLEAN DEFAULT FALSE CHECK (do_not_allow_deletion IN (TRUE, FALSE)),
      is_deletable BOOLEAN DEFAULT FALSE CHECK (is_deletable IN (TRUE, FALSE)),
      created_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
      last_modified_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
      last_modified_by  varchar(22),
      created_by  varchar(22),
      version_number integer DEFAULT 1,
      CONSTRAINT "pk_column" PRIMARY KEY (column_id)
);

-----------------------------------------------------------------
--column_meta
-----------------------------------------------------------------

CREATE INDEX idx_column_meta_id ON production."column_meta"(column_id);
CREATE INDEX idx_column_meta_label ON production."column_meta"("label");
CREATE INDEX idx_column_meta_developer_name ON production."column_meta"(developer_name);
CREATE INDEX idx_column_meta_created_date ON production."column_meta"(created_date);
CREATE INDEX idx_column_meta_last_modified_date ON production."column_meta"(last_modified_date);
CREATE INDEX idx_column_meta_created_by ON production."column_meta"(created_by);
CREATE INDEX idx_column_meta_last_modified_by ON production."column_meta"(last_modified_by);

--Foreign Key For column_meta
ALTER TABLE production."column_meta"
ADD CONSTRAINT fk_column_created_by FOREIGN KEY (created_by) REFERENCES production."user" (user_id) ON DELETE SET NULL;

ALTER TABLE production."column_meta"
ADD CONSTRAINT fk_column_last_modified_by FOREIGN KEY (last_modified_by) REFERENCES production."user" (user_id) ON DELETE SET NULL;
