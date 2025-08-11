-- production.privilege_meta definition

-- Drop table
-- DROP TABLE production.privilege_meta cascade;

CREATE TABLE production.privilege_meta (
	privilege_key serial4 NOT NULL,
	privilege_id varchar(22) GENERATED ALWAYS AS ((('PRV'::text || lpad(privilege_key::text, 19, '0'::text)))) STORED NOT NULL,
	"label" varchar(255) NOT NULL,
	developer_name varchar(255) NOT NULL,
	session_activation_required bool DEFAULT false NULL,
	description varchar(255) NULL,
	created_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
	last_modified_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
	last_modified_by varchar(22) NULL,
	created_by varchar(22) NULL,
	version_number int4 DEFAULT 1 NULL,
	privilege_set_id varchar(22) NULL,
	user_id varchar(22) NULL,
	privilege_code int4 DEFAULT 0 NOT NULL,
	CONSTRAINT pk_privilege PRIMARY KEY (privilege_id),
	CONSTRAINT privilege_meta_developer_name_key UNIQUE (developer_name),
	CONSTRAINT privilege_meta_label_key UNIQUE (label),
	CONSTRAINT privilege_meta_permission_code_key UNIQUE (privilege_code),
	CONSTRAINT privilege_meta_session_activation_required_check CHECK ((session_activation_required = ANY (ARRAY[true, false]))),
	CONSTRAINT fk_privilege_created_by FOREIGN KEY (created_by) REFERENCES production."user"(user_id) ON DELETE SET NULL,
	CONSTRAINT fk_privilege_last_modified_by FOREIGN KEY (last_modified_by) REFERENCES production."user"(user_id) ON DELETE SET NULL,
	CONSTRAINT fk_privilege_meta_user FOREIGN KEY (user_id) REFERENCES production."user"(user_id) ON DELETE SET NULL
);
CREATE INDEX idx_privilege_meta_created_by ON production.privilege_meta USING btree (created_by);
CREATE INDEX idx_privilege_meta_created_date ON production.privilege_meta USING btree (created_date);
CREATE INDEX idx_privilege_meta_developer_name ON production.privilege_meta USING btree (developer_name);
CREATE INDEX idx_privilege_meta_id ON production.privilege_meta USING btree (privilege_id);
CREATE INDEX idx_privilege_meta_label ON production.privilege_meta USING btree (label);
CREATE INDEX idx_privilege_meta_last_modified_by ON production.privilege_meta USING btree (last_modified_by);
CREATE INDEX idx_privilege_meta_last_modified_date ON production.privilege_meta USING btree (last_modified_date);
CREATE UNIQUE INDEX idx_privilege_privilege_code ON production.privilege_meta USING btree (privilege_code);