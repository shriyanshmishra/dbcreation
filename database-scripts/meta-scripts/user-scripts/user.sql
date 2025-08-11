-- production."user" definition

-- Drop table

-- DROP TABLE production."user";

CREATE TABLE production."user" (
	user_key bigserial NOT NULL,
	user_id varchar(22) GENERATED ALWAYS AS ((('USR'::text || lpad(user_key::text, 19, '0'::text)))) STORED NOT NULL,
	first_name varchar(255) NOT NULL,
	last_name varchar(255) NOT NULL,
	default_role varchar(22) NULL,
	country varchar(22) NULL,
	state text NULL,
	city varchar(22) NULL,
	postal_code text NULL,
	"language" varchar(255) NULL,
	phone text NULL,
	mobile text NULL,
	email text NOT NULL,
	active bool DEFAULT false NULL,
	last_password_change timestamptz NULL,
	time_zone text NULL,
	created_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
	last_modified_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
	created_by varchar(22) NULL,
	last_modified_by varchar(22) NULL,
	otp_hash text NULL,
	otp_expires_at timestamptz NULL,
	otp_used bool DEFAULT false NULL,
	alias varchar(255) NULL,
	locale varchar(22) NULL,
	profile text NULL,
	company text NULL,
	department text NULL,
	division text NULL,
	street text NULL,
	nickname text NULL,
	username varchar(255) NOT NULL,
	CONSTRAINT chk_email_lowercase CHECK ((email = lower(email))),
	CONSTRAINT pk_user PRIMARY KEY (user_id),
	CONSTRAINT uq_user_username UNIQUE (username),
	CONSTRAINT user_email_key UNIQUE (email),
	CONSTRAINT fk_user_created_by FOREIGN KEY (created_by) REFERENCES production."user"(user_id) ON DELETE SET NULL,
	CONSTRAINT fk_user_last_modified_by FOREIGN KEY (last_modified_by) REFERENCES production."user"(user_id) ON DELETE SET NULL
);
CREATE INDEX idx_user_created_by ON production."user" USING btree (created_by);
CREATE INDEX idx_user_created_date ON production."user" USING btree (created_date);
CREATE INDEX idx_user_email ON production."user" USING btree (email);
CREATE INDEX idx_user_first_name ON production."user" USING btree (first_name);
CREATE INDEX idx_user_id ON production."user" USING btree (user_id);
CREATE INDEX idx_user_last_modified ON production."user" USING btree (last_modified_date);
CREATE INDEX idx_user_last_modified_by ON production."user" USING btree (last_modified_by);
CREATE INDEX idx_user_last_name ON production."user" USING btree (last_name);
CREATE UNIQUE INDEX idx_user_username ON production."user" USING btree (username);