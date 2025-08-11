-----------------------------------------------------------------
--public_group
-----------------------------------------------------------------
CREATE TABLE production."public_group_meta" (
     public_group_key serial NOT NULL,
     public_group_id  varchar(22) GENERATED ALWAYS AS ('PBG' || LPAD(public_group_key::TEXT, 19, '0')) STORED,
     "label" VARCHAR(255) UNIQUE NOT NULL,
     developer_name VARCHAR(255) UNIQUE NOT NULL,
     description VARCHAR(255),
     created_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
     last_modified_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
     last_modified_by  varchar(22),
     created_by  varchar(22),
     version_number integer DEFAULT 1,
     CONSTRAINT "pk_public_group" PRIMARY KEY (public_group_id)
);


-----------------------------------------------------------------
--public_group
-----------------------------------------------------------------
CREATE INDEX idx_public_group_meta_id ON production."public_group_meta"(public_group_id);
CREATE INDEX idx_public_group_meta_label ON production."public_group_meta"("label");
CREATE INDEX idx_public_group_meta_developer_name ON production."public_group_meta"(developer_name);
CREATE INDEX idx_public_group_meta_created_date ON production."public_group_meta"(created_date);
CREATE INDEX idx_public_group_meta_last_modified_date ON production."public_group_meta"(last_modified_date);
CREATE INDEX idx_public_group_meta_created_by ON production."public_group_meta"(created_by);
CREATE INDEX idx_public_group_meta_last_modified_by ON production."public_group_meta"(last_modified_by);


--Foreign Key For public_group_meta
ALTER TABLE production."public_group_meta"
ADD CONSTRAINT fk_public_group_created_by FOREIGN KEY (created_by) REFERENCES production."user" (user_id) ON DELETE SET NULL;

ALTER TABLE production."public_group_meta"
ADD CONSTRAINT fk_public_group_last_modified_by FOREIGN KEY (last_modified_by) REFERENCES production."user" (user_id) ON DELETE SET NULL;

