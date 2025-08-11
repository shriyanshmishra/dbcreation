-- production.app_privilege_link definition
-- Drop table
-- DROP TABLE production.app_privilege_link;
CREATE TABLE production.app_privilege_link_meta (
	app_privilege_link_key serial4 NOT NULL,
	app_privilege_link_id varchar(22) GENERATED ALWAYS AS ((('APL'::text || lpad(app_privilege_link_key::text, 19, '0'::text)))) STORED NOT NULL,
	app_id varchar(22) NOT NULL,
	privilege_id varchar(22) NULL,
	privilege_set_id varchar(22) NULL,
	created_at timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
	created_by varchar(22) NULL,
	last_modified_at timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
	last_modified_by varchar(22) NULL,
	is_active bool DEFAULT true NULL,
	sort_order int4 DEFAULT 0 NULL,
	version_number int4 DEFAULT 1 NULL,
	is_latest bool DEFAULT true NULL,
	CONSTRAINT app_privilege_link_pkey PRIMARY KEY (app_privilege_link_key),
	CONSTRAINT chk_one_priv_type CHECK ((((privilege_id IS NOT NULL) AND (privilege_set_id IS NULL)) OR ((privilege_id IS NULL) AND (privilege_set_id IS NOT NULL)))),
	CONSTRAINT uq_app_privilege UNIQUE (app_id, privilege_id),
	CONSTRAINT uq_app_privilege_set UNIQUE (app_id, privilege_set_id),
	CONSTRAINT fk_app FOREIGN KEY (app_id) REFERENCES production.app_meta(app_id) ON DELETE CASCADE,
	CONSTRAINT fk_created_by FOREIGN KEY (created_by) REFERENCES production."user"(user_id) ON DELETE SET NULL,
	CONSTRAINT fk_last_modified_by FOREIGN KEY (last_modified_by) REFERENCES production."user"(user_id) ON DELETE SET NULL,
	CONSTRAINT fk_privilege FOREIGN KEY (privilege_id) REFERENCES production.privilege_meta(privilege_id) ON DELETE CASCADE,
	CONSTRAINT fk_privilege_set FOREIGN KEY (privilege_set_id) REFERENCES production.privilege_set_meta(privilege_set_id) ON DELETE CASCADE
);
CREATE INDEX idx_app_privilege_app_id ON production.app_privilege_link USING btree (app_id);
CREATE INDEX idx_app_privilege_privilege_id ON production.app_privilege_link USING btree (privilege_id);
CREATE INDEX idx_app_privilege_privilege_set_id ON production.app_privilege_link USING btree (privilege_set_id);


