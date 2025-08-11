-----------------------------------------------------------------
--entity_meta Schema
-----------------------------------------------------------------
CREATE TABLE production.entity_meta (
     entity_key smallserial NOT NULL,
     entity_id  varchar(22) GENERATED ALWAYS AS ('ENT' || lpad(entity_key::text, 19, '0'::text)) STORED NOT NULL,
     "label" varchar(255) NOT NULL,
     plural_label varchar(255) NOT NULL,
     developer_name varchar(255) NOT NULL,
     prefix bpchar(3) NOT NULL,
     "description" varchar(2000),
     allow_reports bool DEFAULT false NULL,
     allow_activities bool DEFAULT false NULL,
     track_field_history bool DEFAULT false NULL,
     allow_sharing bool DEFAULT false NULL,
     in_development bool DEFAULT false NULL,
     deployed bool DEFAULT false NULL,
     entity_type TEXT DEFAULT 'data' NULL,
     created_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
     last_modified_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
     last_modified_by  varchar(22),
     created_by varchar(22),
     version_number int4 DEFAULT 1 NULL,
     data_space varchar(255) NULL,
     package_name varchar(22) NULL,
	 package_prefix varchar(12) NULL,
     CONSTRAINT entity_meta_allow_activities_check CHECK ((allow_activities = ANY (ARRAY[true, false]))),
     CONSTRAINT entity_meta_allow_reports_check CHECK ((allow_reports = ANY (ARRAY[true, false]))),
     CONSTRAINT entity_meta_allow_sharing_check CHECK ((allow_sharing = ANY (ARRAY[true, false]))),
     CONSTRAINT entity_meta_deployed_check CHECK ((deployed = ANY (ARRAY[true, false]))),
     CONSTRAINT entity_meta_developer_name_key UNIQUE (developer_name),
     CONSTRAINT entity_meta_in_development_check CHECK ((in_development = ANY (ARRAY[true, false]))),
     CONSTRAINT entity_meta_track_field_history_check CHECK ((track_field_history = ANY (ARRAY[true, false]))),
     CONSTRAINT entity_meta_entity_type CHECK ((entity_type  = ANY (ARRAY['data','share','meta']))),
     CONSTRAINT unique_prefix UNIQUE (prefix),
     CONSTRAINT pk_entity PRIMARY KEY (entity_id)
);


-----------------------------------------------------------------
--entity_meta Indexes
-----------------------------------------------------------------

CREATE INDEX idx_entity_meta_created_by ON production.entity_meta USING btree (created_by);
CREATE INDEX idx_entity_meta_created_date ON production.entity_meta USING btree (created_date);
CREATE INDEX idx_entity_meta_last_modified_date ON production.entity_meta USING btree (last_modified_date);
CREATE INDEX idx_entity_meta_developer_name ON production.entity_meta USING btree (developer_name);
CREATE INDEX idx_entity_meta_id ON production.entity_meta USING btree (entity_id);
CREATE INDEX idx_entity_meta_label ON production.entity_meta USING btree (label);
CREATE INDEX idx_entity_meta_last_modified_by ON production.entity_meta USING btree (last_modified_by);
CREATE INDEX idx_entity_meta_prefix ON production.entity_meta USING btree (prefix);

--Foreign Key For entity_meta
ALTER TABLE production."entity_meta"
ADD CONSTRAINT fk_entity_created_by FOREIGN KEY (created_by) REFERENCES production."user" (user_id) ON DELETE SET NULL;

ALTER TABLE production."entity_meta"
ADD CONSTRAINT fk_entity_last_modified_by FOREIGN KEY (last_modified_by) REFERENCES production."user" (user_id) ON DELETE SET NULL;