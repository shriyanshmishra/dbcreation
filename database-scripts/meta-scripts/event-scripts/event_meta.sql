-----------------------------------------------------------------
--event_meta
-----------------------------------------------------------------
CREATE TABLE production."event_meta"(
         event_key bigserial NOT NULL,
         event_id  varchar(22) GENERATED ALWAYS AS ('EVT' || LPAD(event_key::TEXT, 19, '0')) STORED,
         "label" VARCHAR(255) UNIQUE NOT NULL,
         developer_name VARCHAR(255) UNIQUE NOT NULL,
         activity_id  varchar(22) NOT NULL REFERENCES production."activity_meta"(activity_id) ON DELETE CASCADE,
         name_entity_id  varchar(22) NOT NULL REFERENCES production."entity_meta"(entity_id) ON DELETE CASCADE,
         related_to_entity_id  varchar(22) NOT NULL REFERENCES production."entity_meta"(entity_id) ON DELETE SET NULL,
         assigned_to  varchar(22),
         start_time TIMESTAMP NOT NULL,
         end_time TIMESTAMP NOT NULL,
         entity_id  varchar(22) NOT NULL REFERENCES production."entity_meta"(entity_id) ON DELETE CASCADE,
         is_all_day BOOLEAN DEFAULT FALSE CHECK (is_all_day IN (TRUE, FALSE)),
         "location" VARCHAR(255),
         created_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
         last_modified_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
         last_modified_by  varchar(22),
         created_by  varchar(22),
         version_number integer DEFAULT 1,
         CONSTRAINT "pk_event_meta" PRIMARY KEY (event_id)
);


-----------------------------------------------------------------
--event_meta
-----------------------------------------------------------------
CREATE INDEX idx_event_meta_id ON production."event_meta"(event_id);
CREATE INDEX idx_event_meta_label ON production."event_meta"("label");
CREATE INDEX idx_event_meta_developer_name ON production."event_meta"(developer_name);
CREATE INDEX idx_event_meta_created_date ON production."event_meta"(created_date);
CREATE INDEX idx_event_meta_last_modified_date ON production."event_meta"(last_modified_date);
CREATE INDEX idx_event_meta_created_by ON production."event_meta"(created_by);
CREATE INDEX idx_event_meta_last_modified_by ON production."event_meta"(last_modified_by);


--Foreign Key For event_meta
ALTER TABLE production."event_meta"
ADD CONSTRAINT fk_event_created_by FOREIGN KEY (created_by) REFERENCES production."user" (user_id) ON DELETE SET NULL;

ALTER TABLE production."event_meta"
ADD CONSTRAINT fk_event_last_modified_by FOREIGN KEY (last_modified_by) REFERENCES production."user" (user_id) ON DELETE SET NULL;
