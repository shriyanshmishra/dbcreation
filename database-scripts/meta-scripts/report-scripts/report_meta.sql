
-----------------------------------------------------------------
--reports_meta
-----------------------------------------------------------------
CREATE TABLE production."report_meta"(
      report_key serial NOT NULL,
      report_id  varchar(22) GENERATED ALWAYS AS ('RPT' || LPAD(report_key::TEXT, 19, '0')) STORED,
      "label" varchar(255) UNIQUE NOT NULL,
      developer_name VARCHAR(255) UNIQUE NOT NULL,
      entity_id  varchar(22) NOT NULL REFERENCES production."entity_meta"(entity_id) ON DELETE CASCADE,
      report_type VARCHAR(100) NOT NULL CHECK (report_type IN ('Summary', 'Tabular', 'Matrix', 'Joined')),
      description varchar(255),
      created_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
      last_modified_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
      last_modified_by  varchar(22),
      created_by  varchar(22),
      version_number integer DEFAULT 1,
      CONSTRAINT "pk_report" PRIMARY KEY (report_id)
);


-----------------------------------------------------------------
--reports_meta
-----------------------------------------------------------------

CREATE INDEX idx_report_meta_id ON production."report_meta"(report_id);
CREATE INDEX idx_report_meta_label ON production."report_meta"("label");
CREATE INDEX idx_report_meta_developer_name ON production."report_meta"(developer_name);
CREATE INDEX idx_report_meta_created_date ON production."report_meta"(created_date);
CREATE INDEX idx_report_meta_last_modified_date ON production."report_meta"(last_modified_date);
CREATE INDEX idx_report_meta_created_by ON production."report_meta"(created_by);
CREATE INDEX idx_report_meta_last_modified_by ON production."report_meta"(last_modified_by);


--Foreign Key For report_meta
ALTER TABLE production."report_meta"
ADD CONSTRAINT fk_report_created_by FOREIGN KEY (created_by) REFERENCES production."user" (user_id) ON DELETE SET NULL;

ALTER TABLE production."report_meta"
ADD CONSTRAINT fk_report_last_modified_by FOREIGN KEY (last_modified_by) REFERENCES production."user" (user_id) ON DELETE SET NULL;
