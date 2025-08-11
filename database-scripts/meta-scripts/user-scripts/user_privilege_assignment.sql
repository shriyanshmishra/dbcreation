-----------------------------------------------------------------
--user_privilege_assignment (junction)
-----------------------------------------------------------------
CREATE TABLE production."user_privilege_assignment"(
    user_privilege_assignment_key bigserial NOT NULL,
    user_privilege_assignment_id  varchar(22) GENERATED ALWAYS AS ('UPA' || LPAD(user_privilege_assignment_key::TEXT, 19, '0')) STORED,
    "label" VARCHAR(255) UNIQUE NOT NULL,
    developer_name VARCHAR(255) UNIQUE NOT NULL,
    privilege_id varchar(22) NOT NULL REFERENCES production."privilege_meta"(privilege_id) ON DELETE CASCADE,
    user_id varchar(22) NOT NULL REFERENCES production."user"(user_id) ON DELETE CASCADE,
    created_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
    last_modified_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
    last_modified_by varchar(22) ,
    created_by varchar(22) ,
    version_number integer DEFAULT 1,
    CONSTRAINT "pk_user_privilege_assignment" PRIMARY KEY (user_privilege_assignment_id)
);


-----------------------------------------------------------------
--user_privilege_assignment (junction)
-----------------------------------------------------------------
CREATE INDEX idx_user_privilege_assignment_id ON production."user_privilege_assignment"(user_privilege_assignment_id);
CREATE INDEX idx_user_privilege_assignment_label ON production."user_privilege_assignment"("label");
CREATE INDEX idx_user_privilege_assignment_developer_name ON production."user_privilege_assignment"(developer_name);
CREATE INDEX idx_user_privilege_assignment_created_date ON production."user_privilege_assignment"(created_date);
CREATE INDEX idx_user_privilege_assignment_last_modified_date ON production."user_privilege_assignment"(last_modified_date);
CREATE INDEX idx_user_privilege_assignment_created_by ON production."user_privilege_assignment"(created_by);
CREATE INDEX idx_user_privilege_assignment_last_modified_by ON production."user_privilege_assignment"(last_modified_by);


--Foreign Key For user_privilege_assignment
ALTER TABLE production."user_privilege_assignment"
ADD CONSTRAINT fk_user_privilege_assignment_created_by FOREIGN KEY (created_by) REFERENCES production."user" (user_id) ON DELETE SET NULL;

ALTER TABLE production."user_privilege_assignment"
ADD CONSTRAINT fk_user_privilege_assignment_last_modified_by FOREIGN KEY (last_modified_by) REFERENCES production."user" (user_id) ON DELETE SET NULL;
