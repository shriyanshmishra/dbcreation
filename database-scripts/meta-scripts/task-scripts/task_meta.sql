-----------------------------------------------------------------
--task_meta
-----------------------------------------------------------------
CREATE TABLE production."task_meta"(
        task_key bigserial NOT NULL,
        task_id  varchar(22) GENERATED ALWAYS AS ('TSK' || LPAD(task_key::TEXT, 19, '0')) STORED,
        "label" VARCHAR(255) UNIQUE NOT NULL,
        developer_name VARCHAR(255) UNIQUE NOT NULL,
        assigned_to  varchar(22),
        activity_id  varchar(22) NOT NULL REFERENCES production."activity_meta"(activity_id) ON DELETE CASCADE,
        name_entity_id  varchar(22) NOT NULL REFERENCES production."entity_meta"(entity_id) ON DELETE CASCADE,
        subject VARCHAR(255) NOT NULL,
        due_date DATE NOT NULL,
        related_to_entity_id  varchar(22) NOT NULL REFERENCES production."entity_meta"(entity_id) ON DELETE CASCADE,
        priority VARCHAR(50) CHECK (priority IN ('Low', 'Medium', 'High')),
        status VARCHAR(50) CHECK (status IN ('Pending', 'In Progress', 'Completed', 'Cancelled')),
        task_reminder VARCHAR(255),
        created_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
        last_modified_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
        last_modified_by  varchar(22),
        created_by  varchar(22),
        version_number integer DEFAULT 1,
        CONSTRAINT "pk_task_meta" PRIMARY KEY (task_id)
);


-----------------------------------------------------------------
--task_meta
-----------------------------------------------------------------
CREATE INDEX idx_task_meta_id ON production."task_meta"(task_id);
CREATE INDEX idx_task_meta_label ON production."task_meta"("label");
CREATE INDEX idx_task_meta_developer_name ON production."task_meta"(developer_name);
CREATE INDEX idx_task_meta_created_date ON production."task_meta"(created_date);
CREATE INDEX idx_task_meta_last_modified_date ON production."task_meta"(last_modified_date);
CREATE INDEX idx_task_meta_created_by ON production."task_meta"(created_by);
CREATE INDEX idx_task_meta_last_modified_by ON production."task_meta"(last_modified_by);



--Foreign Key For task_meta
ALTER TABLE production."task_meta"
ADD CONSTRAINT fk_task_assigned_to FOREIGN KEY (assigned_to) REFERENCES production."user" (user_id) ON DELETE SET NULL;

ALTER TABLE production."task_meta"
ADD CONSTRAINT fk_task_created_by FOREIGN KEY (created_by) REFERENCES production."user" (user_id) ON DELETE SET NULL;

ALTER TABLE production."task_meta"
ADD CONSTRAINT fk_task_last_modified_by FOREIGN KEY (last_modified_by) REFERENCES production."user" (user_id) ON DELETE SET NULL;

