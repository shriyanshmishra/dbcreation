-- DROP FUNCTION production.mark_session_inactive(text);

CREATE OR REPLACE FUNCTION production.mark_session_inactive(p_session_id text)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
    UPDATE production.login_session_meta
    SET 
        is_active = FALSE,
        session_end = now(),
        updated_at = now()
    WHERE session_token = p_session_id;

    RAISE NOTICE 'Session marked inactive for session_token: %', p_session_id;
END;
$function$
;
