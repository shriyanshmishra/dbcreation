
-- production.picklist_meta definition
-- Drop table
-- DROP TABLE production.picklist_meta;

CREATE TABLE production.picklist_meta (
	picklist_key bigserial NOT NULL,
	picklist_id varchar(22) GENERATED ALWAYS AS ((('PKL'::text || lpad(picklist_key::text, 19, '0'::text)))) STORED NOT NULL,
	"label" varchar(255) NOT NULL,
	column_id varchar(22) NOT NULL,
	developer_name varchar(255) NOT NULL,
	status varchar(10) DEFAULT 'Active'::character varying NULL,
	"default" bool DEFAULT false NULL,
	created_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
	last_modified_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
	last_modified_by varchar(22) NULL,
	created_by varchar(22) NULL,
	version_number int4 DEFAULT 1 NULL,
	description varchar(2000) NULL,
	CONSTRAINT picklist_meta_default_check CHECK (("default" = ANY (ARRAY[true, false]))),
	CONSTRAINT picklist_meta_status_check CHECK (((status)::text = ANY ((ARRAY['Active'::character varying, 'Inactive'::character varying])::text[]))),
	CONSTRAINT pk_pickilist PRIMARY KEY (picklist_id),
	CONSTRAINT fk_picklist_created_by FOREIGN KEY (created_by) REFERENCES production."user"(user_id) ON DELETE SET NULL,
	CONSTRAINT fk_picklist_last_modified_by FOREIGN KEY (last_modified_by) REFERENCES production."user"(user_id) ON DELETE SET NULL,
	CONSTRAINT picklist_meta_column_id_fkey FOREIGN KEY (column_id) REFERENCES production.column_meta(column_id) ON DELETE CASCADE
);
CREATE INDEX idx_picklist_meta_created_by ON production.picklist_meta USING btree (created_by);
CREATE INDEX idx_picklist_meta_created_date ON production.picklist_meta USING btree (created_date);
CREATE INDEX idx_picklist_meta_developer_name ON production.picklist_meta USING btree (developer_name);
CREATE INDEX idx_picklist_meta_id ON production.picklist_meta USING btree (picklist_id);
CREATE INDEX idx_picklist_meta_label ON production.picklist_meta USING btree (label);
CREATE INDEX idx_picklist_meta_last_modified ON production.picklist_meta USING btree (last_modified_date);
CREATE INDEX idx_picklist_meta_last_modified_by ON production.picklist_meta USING btree (last_modified_by);

