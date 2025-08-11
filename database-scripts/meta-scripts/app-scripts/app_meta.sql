-- production.app_meta definition

-- Drop table

-- DROP TABLE production.app_meta;

CREATE TABLE production.app_meta (
	app_key serial4 NOT NULL,
	app_id varchar(22) GENERATED ALWAYS AS ((('APP'::text || lpad(app_key::text, 19, '0'::text)))) STORED NOT NULL,
	"label" varchar(255) NOT NULL,
	developer_name varchar(255) NOT NULL,
	description text NULL,
	icon bytea NULL,
	is_active bool DEFAULT true NOT NULL,
	created_by varchar(22) NULL,
	created_by_session varchar(36) NULL,
	created_at timestamp DEFAULT CURRENT_TIMESTAMP NULL,
	updated_by varchar(22) NULL,
	updated_by_session varchar(36) NULL,
	updated_at timestamp NULL,
	primary_color_hex varchar(7) DEFAULT '#0070D2'::character varying NULL,
	use_custom_theme bool DEFAULT false NULL,
	navigation_style varchar(20) DEFAULT 'standard'::character varying NULL,
	form_factor varchar(20) DEFAULT 'both'::character varying NULL,
	setup_experience varchar(20) DEFAULT 'full'::character varying NULL,
	disable_nav_personalization bool DEFAULT false NULL,
	disable_temp_tabs bool DEFAULT false NULL,
	use_omni_channel_sidebar bool DEFAULT false NULL,
	version_number int4 DEFAULT 1 NULL,
	is_latest bool DEFAULT true NULL,
	is_archived bool DEFAULT false NULL,
	is_deleted bool DEFAULT false NULL,
	CONSTRAINT app_meta_app_id_unique UNIQUE (app_id),
	CONSTRAINT app_meta_developer_name_key UNIQUE (developer_name),
	CONSTRAINT app_meta_devname_not_empty CHECK ((char_length((developer_name)::text) > 0)),
	CONSTRAINT app_meta_form_factor_check CHECK (((form_factor)::text = ANY (ARRAY[('desktop'::character varying)::text, ('phone'::character varying)::text, ('both'::character varying)::text]))),
	CONSTRAINT app_meta_label_not_empty CHECK ((char_length((label)::text) > 0)),
	CONSTRAINT app_meta_navigation_style_check CHECK (((navigation_style)::text = ANY (ARRAY[('standard'::character varying)::text, ('console'::character varying)::text]))),
	CONSTRAINT app_meta_pkey PRIMARY KEY (app_key),
	CONSTRAINT app_meta_setup_experience_check CHECK (((setup_experience)::text = ANY (ARRAY[('full'::character varying)::text, ('service'::character varying)::text])))
);
CREATE INDEX idx_app_meta_app_id ON production.app_meta USING btree (app_id);
CREATE INDEX idx_app_meta_created_at ON production.app_meta USING btree (created_at);
CREATE INDEX idx_app_meta_created_by ON production.app_meta USING btree (created_by);
CREATE INDEX idx_app_meta_developer_name ON production.app_meta USING btree (developer_name);
CREATE INDEX idx_app_meta_is_active ON production.app_meta USING btree (is_active);
CREATE INDEX idx_app_meta_is_archived ON production.app_meta USING btree (is_archived);
CREATE INDEX idx_app_meta_is_latest ON production.app_meta USING btree (is_latest);
CREATE INDEX idx_app_meta_updated_at ON production.app_meta USING btree (updated_at);
CREATE INDEX idx_app_meta_updated_by ON production.app_meta USING btree (updated_by);
CREATE INDEX idx_app_meta_version_number ON production.app_meta USING btree (version_number);