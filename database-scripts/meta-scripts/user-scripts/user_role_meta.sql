-----------------------------------------------------------------
--user_role_meta
-----------------------------------------------------------------

CREATE TABLE production."user_role_meta"(
         user_role_key serial NOT NULL,
         user_role_id  varchar(22) GENERATED ALWAYS AS ('URO' || LPAD(user_role_key::TEXT, 19, '0')) STORED,
         role_id  varchar(22) NOT NULL REFERENCES production."role_meta"(role_id)ON DELETE CASCADE,
         user_id  varchar(22),
         created_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
         last_modified_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
         last_modified_by  varchar(22),
         created_by  varchar(22),
         version_number integer DEFAULT 1,
         CONSTRAINT "pk_user_role_meta" PRIMARY KEY (user_role_id)
);

-----------------------------------------------------------------
--user_role_meta
-----------------------------------------------------------------
CREATE INDEX idx_user_role_meta_id ON production."user_role_meta"(user_role_id);
CREATE INDEX idx_user_role_meta_created_date ON production."user_role_meta"(created_date);
CREATE INDEX idx_user_role_meta_last_modified_date ON production."user_role_meta"(last_modified_date);
CREATE INDEX idx_user_role_meta_created_by ON production."user_role_meta"(created_by);
CREATE INDEX idx_user_role_meta_last_modified_by ON production."user_role_meta"(last_modified_by);


--Foreign Key For user_role_meta
ALTER TABLE production."user_role_meta"
ADD CONSTRAINT fk_user_role_user_id_meta FOREIGN KEY (user_id) REFERENCES production."user" (user_id) ON DELETE SET NULL;

ALTER TABLE production."user_role_meta"
ADD CONSTRAINT fk_user_role_created_by FOREIGN KEY (created_by) REFERENCES production."user" (user_id) ON DELETE SET NULL;

ALTER TABLE production."user_role_meta"
ADD CONSTRAINT fk_user_role_last_modified_by FOREIGN KEY (last_modified_by) REFERENCES production."user" (user_id) ON DELETE SET NULL;
