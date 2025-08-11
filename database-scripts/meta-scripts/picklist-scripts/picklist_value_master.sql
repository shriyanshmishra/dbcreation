-- production.picklist_value_master definition

-- Drop table

-- DROP TABLE production.picklist_value_master;

CREATE TABLE production.picklist_value_master (
	picklist_value_key bigserial NOT NULL,
	picklist_value_id varchar(22) GENERATED ALWAYS AS ((('PKV'::text || lpad(picklist_value_key::text, 19, '0'::text)))) STORED NOT NULL,
	picklist_id varchar(22) NOT NULL,
	developer_name varchar(255) NOT NULL,
	"label" varchar(255) NOT NULL,
	status varchar(10) DEFAULT 'Active'::character varying NULL,
	"default" bool DEFAULT false NULL,
	sort_order int4 DEFAULT 0 NULL,
	description varchar(2000) NULL,
	created_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
	last_modified_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
	last_modified_by varchar(22) NULL,
	created_by varchar(22) NULL,
	version_number int4 DEFAULT 1 NULL,
	CONSTRAINT picklist_value_master_status_check CHECK (((status)::text = ANY ((ARRAY['Active'::character varying, 'Inactive'::character varying])::text[]))),
	CONSTRAINT pk_picklist_value PRIMARY KEY (picklist_value_id),
	CONSTRAINT fk_picklist_value_created_by FOREIGN KEY (created_by) REFERENCES production."user"(user_id) ON DELETE SET NULL,
	CONSTRAINT fk_picklist_value_last_modified_by FOREIGN KEY (last_modified_by) REFERENCES production."user"(user_id) ON DELETE SET NULL,
	CONSTRAINT fk_picklist_value_picklist FOREIGN KEY (picklist_id) REFERENCES production.picklist_meta(picklist_id) ON DELETE CASCADE
);
CREATE INDEX idx_picklist_value_created_date ON production.picklist_value_master USING btree (created_date);
CREATE INDEX idx_picklist_value_developer_name ON production.picklist_value_master USING btree (developer_name);
CREATE INDEX idx_picklist_value_label ON production.picklist_value_master USING btree (label);
CREATE INDEX idx_picklist_value_last_modified_date ON production.picklist_value_master USING btree (last_modified_date);
CREATE INDEX idx_picklist_value_picklist_id ON production.picklist_value_master USING btree (picklist_id);
CREATE INDEX idx_picklist_value_status ON production.picklist_value_master USING btree (status);