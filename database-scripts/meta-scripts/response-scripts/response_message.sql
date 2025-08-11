-- production.response_message definition
-- Drop table
-- DROP TABLE production.response_message;
CREATE TABLE production.response_message (
    response_message_key bigserial NOT NULL,
    response_message_id text GENERATED ALWAYS AS ('RMG'::text || lpad(response_message_key::text, 19, '0'::text)) STORED NULL,
    code varchar(255) NOT NULL,
    locale varchar(10) NOT NULL,
    response_message varchar(32767) NOT NULL,
    is_default bool DEFAULT false NULL,
    created_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
	last_modified_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
	created_by varchar(22) NULL,
	last_modified_by varchar(22) NULL,
	version_number int4 DEFAULT 1 NULL,

    CONSTRAINT response_message_locale_check CHECK ((length(locale) = 10)),
    CONSTRAINT response_message_pkey PRIMARY KEY (code, locale),
    CONSTRAINT fk_response_code FOREIGN KEY (code) REFERENCES production.response_code(code) ON DELETE CASCADE
);
CREATE INDEX idx_response_message_code_locale ON production.response_message USING btree (code, locale);
CREATE INDEX idx_response_message_default ON production.response_message USING btree (code) WHERE (is_default = true);