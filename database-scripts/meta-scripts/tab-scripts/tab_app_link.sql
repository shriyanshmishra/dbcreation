-- production.tab_app_link definition
-- Drop table
-- DROP TABLE production.tab_app_link;
CREATE TABLE production.tab_app_link (
	tab_app_link_key serial4 NOT NULL,
	tab_app_link_id varchar(22) GENERATED ALWAYS AS ((('TAL'::text || lpad(tab_app_link_key::text, 19, '0'::text)))) STORED NOT NULL,
	tab_id varchar(22) NOT NULL,
	app_id varchar(22) NOT NULL,
	sort_order int4 DEFAULT 0 NULL,
	is_active bool DEFAULT true NULL,
	created_at timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
	created_by varchar(22) NULL,
	last_modified_at timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
	last_modified_by varchar(22) NULL,
	version_number int4 DEFAULT 1 NULL,
	is_latest bool DEFAULT true NULL,
	entity_id text NULL,
	"label" text NULL,
	CONSTRAINT tab_app_link_pkey PRIMARY KEY (tab_app_link_key),
	CONSTRAINT uq_tab_app UNIQUE (tab_id, app_id),
	CONSTRAINT fk_app FOREIGN KEY (app_id) REFERENCES production.app_meta(app_id) ON DELETE CASCADE,
	CONSTRAINT fk_created_by FOREIGN KEY (created_by) REFERENCES production."user"(user_id) ON DELETE SET NULL,
	CONSTRAINT fk_last_modified_by FOREIGN KEY (last_modified_by) REFERENCES production."user"(user_id) ON DELETE SET NULL,
	CONSTRAINT fk_tab FOREIGN KEY (tab_id) REFERENCES production.tab_meta(tab_id) ON DELETE CASCADE
);
CREATE INDEX idx_tab_app_app_id ON production.tab_app_link USING btree (app_id);
CREATE INDEX idx_tab_app_tab_id ON production.tab_app_link USING btree (tab_id);
CREATE UNIQUE INDEX unique_tab_entity_app_label_ci ON production.tab_app_link USING btree (entity_id, app_id, lower(label));
