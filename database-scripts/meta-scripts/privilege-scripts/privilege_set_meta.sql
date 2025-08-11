-- production.privilege_set_meta definition

-- Drop table

-- DROP TABLE production.privilege_set_meta;

CREATE TABLE production.privilege_set_meta (
	privilege_set_key serial4 NOT NULL,
	privilege_set_id varchar(22) GENERATED ALWAYS AS ((('PST'::text || lpad(privilege_set_key::text, 19, '0'::text)))) STORED NULL,
	"label" varchar(255) NOT NULL,
	developer_name varchar(255) NOT NULL,
	description text NULL,
	created_by varchar(22) NULL,
	created_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
	last_modified_by varchar(22) NULL,
	last_modified_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
	role_id varchar(22) NULL,
	session_activation_required bool DEFAULT false NULL,
	CONSTRAINT privilege_set_meta_developer_name_key UNIQUE (developer_name),
	CONSTRAINT privilege_set_meta_pkey PRIMARY KEY (privilege_set_key),
	CONSTRAINT uq_privilege_set_id UNIQUE (privilege_set_id),
	CONSTRAINT fk_privilege_set_role_id FOREIGN KEY (role_id) REFERENCES production.role_meta(role_id) ON DELETE SET NULL,
	CONSTRAINT fk_pset_created_by FOREIGN KEY (created_by) REFERENCES production."user"(user_id) ON DELETE SET NULL,
	CONSTRAINT fk_pset_modified_by FOREIGN KEY (last_modified_by) REFERENCES production."user"(user_id) ON DELETE SET NULL
);
CREATE INDEX idx_privilege_set_meta_role_id ON production.privilege_set_meta USING btree (role_id);