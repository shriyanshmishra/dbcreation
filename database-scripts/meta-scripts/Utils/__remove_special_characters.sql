-- DROP FUNCTION IF EXISTS production.remove_special_characters(text);

CREATE OR REPLACE FUNCTION production.remove_special_characters(input_string text)
RETURNS text
LANGUAGE plpgsql
AS $function$
BEGIN
    -- Allow letters, digits, underscores, and spaces
    -- Then replace spaces with underscores
    RETURN REPLACE(
        REGEXP_REPLACE(input_string, '[^a-zA-Z0-9_ ]', '', 'g'),
        ' ',
        '_'
    );
END;
$function$;
