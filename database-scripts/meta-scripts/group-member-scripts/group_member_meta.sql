-----------------------------------------------------------------
--group_member
-----------------------------------------------------------------
CREATE TABLE production."group_member_meta" (
      group_member_key serial NOT NULL,
      group_member_id  varchar(22) GENERATED ALWAYS AS ('PBM' || LPAD(group_member_key::TEXT, 19, '0')) STORED,
      public_group_id  varchar(22),
      "label" VARCHAR(255) UNIQUE NOT NULL,
      developer_name VARCHAR(255) UNIQUE NOT NULL,
      user_id  varchar(22),
      created_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
      last_modified_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
      last_modified_by  varchar(22),
      created_by  varchar(22),
      version_number integer DEFAULT 1,
      CONSTRAINT "pk_group_member" PRIMARY KEY (group_member_id)
);



-----------------------------------------------------------------
--group_member
-----------------------------------------------------------------
CREATE INDEX idx_group_member_meta_id ON production."group_member_meta"(group_member_id);
CREATE INDEX idx_group_member_meta_label ON production."group_member_meta"("label");
CREATE INDEX idx_group_member_meta_developer_name ON production."group_member_meta"(developer_name);
CREATE INDEX idx_group_member_meta_created_date ON production."group_member_meta"(created_date);
CREATE INDEX idx_group_member_meta_last_modified_date ON production."group_member_meta"(last_modified_date);
CREATE INDEX idx_group_member_meta_created_by ON production."group_member_meta"(created_by);
CREATE INDEX idx_group_member_meta_last_modified_by ON production."group_member_meta"(last_modified_by);

--Foreign Key For group_member_meta
ALTER TABLE production."group_member_meta"
ADD CONSTRAINT fk_group_member_public_group_id FOREIGN KEY (public_group_id) REFERENCES production."public_group_meta" (public_group_id) ON DELETE SET NULL;

ALTER TABLE production."group_member_meta"
ADD CONSTRAINT fk_group_member_created_by FOREIGN KEY (created_by) REFERENCES production."user" (user_id) ON DELETE SET NULL;

ALTER TABLE production."group_member_meta"
ADD CONSTRAINT fk_group_member_last_modified_by FOREIGN KEY (last_modified_by) REFERENCES production."user" (user_id) ON DELETE SET NULL;

