-- production.tab_meta definition

-- Drop table

 --DROP TABLE production.tab_meta cascade;

CREATE TABLE production.tab_meta (
	tab_key serial4 NOT NULL,
	tab_id varchar(22) GENERATED ALWAYS AS ((('TAB'::text || lpad(tab_key::text, 19, '0'::text)))) STORED NOT NULL,
	"label" varchar(255) NOT NULL,
	developer_name varchar(255) NOT NULL,
	entity_id varchar(22) NOT NULL,
	description varchar(255) NULL,
	version_number int4 DEFAULT 1 NULL,
	created_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
	last_modified_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
	created_by varchar(22) NULL,
	last_modified_by varchar(22) NULL,
	is_restricted bool DEFAULT false NULL,
	tab_style bytea NULL,
	CONSTRAINT tab_meta_devname_unique UNIQUE (developer_name),
	CONSTRAINT tab_meta_pk PRIMARY KEY (tab_id),
	CONSTRAINT fk_tab_created_by FOREIGN KEY (created_by) REFERENCES production."user"(user_id) ON DELETE SET NULL,
	CONSTRAINT fk_tab_entity FOREIGN KEY (entity_id) REFERENCES production.entity_meta(entity_id) ON DELETE CASCADE,
	CONSTRAINT fk_tab_last_modified_by FOREIGN KEY (last_modified_by) REFERENCES production."user"(user_id) ON DELETE SET NULL
);
CREATE INDEX idx_tab_meta_created_by ON production.tab_meta USING btree (created_by);
CREATE INDEX idx_tab_meta_entity ON production.tab_meta USING btree (entity_id);
CREATE INDEX idx_tab_meta_last_modified_by ON production.tab_meta USING btree (last_modified_by);