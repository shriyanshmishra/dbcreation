-----------------------------------------------------------------
-- privilege_set_assignment_meta
-----------------------------------------------------------------
CREATE TABLE production."privilege_set_assignment_meta" (
    assignment_key serial NOT NULL,
    privilege_set_id varchar(22) NOT NULL,
    user_id varchar(22),
    role_id varchar(22),
    assigned_by varchar(22),
    assigned_date timestamptz DEFAULT CURRENT_TIMESTAMP,
    description varchar(255) NULL,
    created_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
    last_modified_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
    last_modified_by varchar(22) NULL,
    created_by varchar(22) NULL,
    version_number int4 DEFAULT 1 NULL,

    CONSTRAINT privilege_set_assignment_meta_pkey PRIMARY KEY (privilege_set_id),
    CONSTRAINT chk_one_target CHECK (
        (user_id IS NOT NULL AND role_id IS NULL) OR 
        (user_id IS NULL AND role_id IS NOT NULL)
    )
);

-----------------------------------------------------------------
-- Indexes for privilege_set_assignment_meta
-----------------------------------------------------------------
CREATE INDEX idx_psa_privilege_set_id ON production."privilege_set_assignment_meta"(privilege_set_id);
CREATE INDEX idx_psa_user_id ON production."privilege_set_assignment_meta"(user_id);
CREATE INDEX idx_psa_role_id ON production."privilege_set_assignment_meta"(role_id);
CREATE INDEX idx_psa_assigned_by ON production."privilege_set_assignment_meta"(assigned_by);
CREATE INDEX idx_psa_assigned_date ON production."privilege_set_assignment_meta"(assigned_date);

-----------------------------------------------------------------
-- Foreign Keys for privilege_set_assignment_meta
-----------------------------------------------------------------
ALTER TABLE production."privilege_set_assignment_meta"
ADD CONSTRAINT fk_psa_set FOREIGN KEY (privilege_set_id)
REFERENCES production."privilege_set_meta"(privilege_set_id) ON DELETE CASCADE;

ALTER TABLE production."privilege_set_assignment_meta"
ADD CONSTRAINT fk_psa_user FOREIGN KEY (user_id)
REFERENCES production."user"(user_id) ON DELETE CASCADE;

ALTER TABLE production."privilege_set_assignment_meta"
ADD CONSTRAINT fk_psa_role FOREIGN KEY (role_id)
REFERENCES production."role_meta"(role_id) ON DELETE CASCADE;

ALTER TABLE production."privilege_set_assignment_meta"
ADD CONSTRAINT fk_psa_assigned_by FOREIGN KEY (assigned_by)
REFERENCES production."user"(user_id) ON DELETE SET NULL;
