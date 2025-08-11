CREATE OR REPLACE FUNCTION production.create_entity_share_table_function(
    item jsonb,
    meta_data_space text,
    meta_table text,
    user_id character varying
)
RETURNS text
LANGUAGE plpgsql
AS $function$
DECLARE
    next_prefix bpchar(3);
    dev_name varchar(255);
BEGIN
    -- Preserve casing of developer_name
    dev_name := production.remove_special_characters(item->>'developer_name');
    RAISE NOTICE 'Preserved-case developer_name: %', dev_name;

    -- Generate next prefix like S01, S02, ...
    SELECT 'S' || LPAD((COALESCE(MAX(CAST(SUBSTRING(prefix FROM 2) AS INTEGER)), 0) + 1)::TEXT, 2, '0')
    INTO next_prefix
    FROM production.entity_meta
    WHERE entity_type = 'share';

    -- Create share table with quoted identifiers
	 RAISE NOTICE 'Next Prefix: %', next_prefix;
	RAISE NOTICE 'developer_name: %',dev_name;
    EXECUTE format(
        'CREATE TABLE IF NOT EXISTS %I.%I (
            %I smallserial NOT NULL,
            %I varchar(22) GENERATED ALWAYS AS (%L || LPAD(%I::TEXT, 19, ''0'')) STORED,
            record_id varchar(22),
            user_id varchar(22) NULL REFERENCES production."user"(user_id) ON DELETE CASCADE,
            group_id varchar(22) NULL REFERENCES production."public_group_meta"(public_group_id) ON DELETE CASCADE,
            account_access_level VARCHAR(50) CHECK (account_access_level IN (''Read Only'', ''Read/Write'')),
            opportunity_access_level VARCHAR(50) CHECK (opportunity_access_level IN (''Read Only'', ''Read/Write'')),
            case_access_level VARCHAR(50) CHECK (case_access_level IN (''Read Only'', ''Read/Write'')),
            contact_access_level VARCHAR(50) CHECK (contact_access_level IN (''Read Only'', ''Read/Write'')),
            created_date TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
            last_modified_date TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
            created_by varchar(22) NOT NULL REFERENCES production."user"(user_id) ON DELETE CASCADE,
            last_modified_by varchar(22) NOT NULL REFERENCES production."user"(user_id) ON DELETE CASCADE,
            version_number INTEGER DEFAULT 1,
            CONSTRAINT %I PRIMARY KEY (%I)
        );',
        meta_data_space, dev_name || '_share',
        dev_name || '_share_key',
        dev_name || '_share_id',
        next_prefix,
        dev_name || '_share_key',
        'pk_' || dev_name || '_share',
        dev_name || '_share_id'
    );

    -- Insert entity metadata
    EXECUTE format(
        'INSERT INTO %I.%I (
            label, plural_label, prefix, developer_name,
            entity_type, allow_reports, allow_activities, track_field_history,
            allow_sharing, in_development, deployed, data_space,
            last_modified_by, created_by
        ) VALUES (
            $1, $2, $3, $4,
            ''share'', FALSE, FALSE, FALSE,
            TRUE, FALSE, TRUE, $5,
            $6, $7
        );',
        meta_data_space, meta_table
    ) USING
        item->>'label' || ' Share',
        item->>'plural_label' || ' Shares',
        next_prefix,
        dev_name || '_share',
        meta_data_space,
        user_id, user_id;

    -- Create indexes for the share table
	RAISE NOTICE 'Inserted share table metadata into %I.%I for %', meta_data_space, meta_table, (item->>'label')||' Share';

	RAISE NOTICE 'All Data : % , % , % , % ', item->>'label', item->>'plural_label', dev_name, meta_data_space;
	    IF EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = meta_data_space
        AND table_name = dev_name || '_share'
    ) THEN
	RAISE NOTICE 'table name % & %:',meta_data_space, meta_table;
	    -- Creating indexes for Share Table
	        EXECUTE format(
            'CREATE INDEX IF NOT EXISTS %I ON %I.%I (created_by);',
            'idx_' || dev_name || '_share_created_by',
            meta_data_space,
            dev_name || '_share'
        );
        EXECUTE format(
            'CREATE INDEX IF NOT EXISTS %I ON %I.%I (last_modified_by);',
            'idx_' || dev_name || '_share_last_modified_by',
            meta_data_space,
            dev_name || '_share'
        );
        EXECUTE format(
            'CREATE INDEX IF NOT EXISTS %I ON %I.%I (last_modified_date);',
            'idx_' || dev_name || '_share_last_modified_date',
            meta_data_space,
            dev_name || '_share'
        );
        EXECUTE format(
            'CREATE INDEX IF NOT EXISTS %I ON %I.%I (created_date);',
            'idx_' || dev_name || '_share_created_date',
            meta_data_space,
            dev_name || '_share'
        );
        EXECUTE format(
            'CREATE INDEX IF NOT EXISTS %I ON %I.%I (%I);',
            'idx_' || dev_name || '_share_id',
            meta_data_space,
            dev_name || '_share',
            dev_name || '_share_id'
        );
    END IF;

    RETURN 'Execution Finished: Share Table created Successfully';
END;
$function$;
