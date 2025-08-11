DO $$ DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT schema_name FROM information_schema.schemata WHERE schema_name != 'public' AND schema_name NOT LIKE 'pg_%' AND schema_name != 'information_schema') LOOP
        EXECUTE 'DROP SCHEMA IF EXISTS ' || r.schema_name || ' CASCADE';
    END LOOP;
END $$;