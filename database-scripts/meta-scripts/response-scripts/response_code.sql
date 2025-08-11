-- DROP TABLE production.response_code;
CREATE TABLE production.response_code (
    response_key bigserial NOT NULL,
    response_id text GENERATED ALWAYS AS ('RES'::text || lpad(response_key::text, 19, '0'::text)) STORED NULL,
    code varchar(255) NOT NULL,
    response_type varchar(255) NOT NULL,
    is_active bool DEFAULT TRUE NULL,
    created_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
	last_modified_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
	created_by varchar(22) NULL,
	last_modified_by varchar(22) NULL,
	version_number int4 DEFAULT 1 NULL,
    CONSTRAINT response_code_pkey PRIMARY KEY (response_key),
    CONSTRAINT response_code_response_type_check CHECK ((response_type = ANY (ARRAY['ERROR'::text, 'SUCCESS'::text,'WARN'::text,'INFO'::text])))
);

CREATE UNIQUE INDEX idx_response_code_code_active ON production.response_code USING btree (code) WHERE (is_active = true);