-- production.tab_privilege_link definition

-- Drop table

-- DROP TABLE production.tab_privilege_link;

CREATE TABLE production.tab_privilege_link (
	tab_privilege_link_key serial4 NOT NULL,
	tab_privilege_link_id varchar(22) GENERATED ALWAYS AS ((('TPL'::text || lpad(tab_privilege_link_key::text, 19, '0'::text)))) STORED NOT NULL,
	tab_id varchar(22) NOT NULL,
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
	CONSTRAINT chk_one_priv_type CHECK ((((privilege_id IS NOT NULL) AND (privilege_set_id IS NULL)) OR ((privilege_id IS NULL) AND (privilege_set_id IS NOT NULL)))),
	CONSTRAINT tab_privilege_link_pkey PRIMARY KEY (tab_privilege_link_key),
	CONSTRAINT uq_tab_privilege UNIQUE (tab_id, privilege_id),
	CONSTRAINT uq_tab_privilege_set UNIQUE (tab_id, privilege_set_id),
	CONSTRAINT fk_created_by FOREIGN KEY (created_by) REFERENCES production."user"(user_id) ON DELETE SET NULL,
	CONSTRAINT fk_last_modified_by FOREIGN KEY (last_modified_by) REFERENCES production."user"(user_id) ON DELETE SET NULL,
	CONSTRAINT fk_privilege FOREIGN KEY (privilege_id) REFERENCES production.privilege_meta(privilege_id) ON DELETE CASCADE,
	CONSTRAINT fk_privilege_set FOREIGN KEY (privilege_set_id) REFERENCES production.privilege_set_meta(privilege_set_id) ON DELETE CASCADE,
	CONSTRAINT fk_tab FOREIGN KEY (tab_id) REFERENCES production.tab_meta(tab_id) ON DELETE CASCADE
);
CREATE INDEX idx_tab_privilege_privilege_id ON production.tab_privilege_link USING btree (privilege_id);
CREATE INDEX idx_tab_privilege_privilege_set_id ON production.tab_privilege_link USING btree (privilege_set_id);
CREATE INDEX idx_tab_privilege_tab_id ON production.tab_privilege_link USING btree (tab_id);