
-----------------------------------------------------------------
--login_sessions
-----------------------------------------------------------------
CREATE TABLE production."login_session_meta" (
    login_session_key smallserial NOT NULL,
    login_session_id  varchar(22) GENERATED ALWAYS AS ('LGN' || lpad(login_session_key::text, 19, '0'::text)) STORED NOT NULL,
    session_id SERIAL PRIMARY KEY,                                                                                     
    user_id varchar(22),                         
    login_provider VARCHAR(50) NOT NULL,                                                                                
    session_token TEXT NOT NULL,                                                                                            
    ip_address VARCHAR(45),                                                                                                 
    user_agent TEXT,                                                                                                        
    session_start timestamptz NOT NULL DEFAULT NOW(),                                                                       
    session_end timestamptz,                                                                                                
    is_active BOOLEAN DEFAULT TRUE,                                                                                         
    created_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
    last_modified_date timestamptz DEFAULT CURRENT_TIMESTAMP NULL,                                                             
    updated_at timestamptz NOT NULL DEFAULT NOW()                                                                      
);


-----------------------------------------------------------------
--login_sessions_meta
-----------------------------------------------------------------
CREATE INDEX idx_login_sessions_meta_id ON production."login_session_meta"(session_id);
CREATE INDEX idx_login_sessions_meta_created_date ON production."login_session_meta"(created_date);
CREATE INDEX idx_login_sessions_meta_last_modified_date ON production."login_session_meta"(last_modified_date);


--Foreign Key For login_sessions_meta
ALTER TABLE production."login_session_meta"
ADD CONSTRAINT fk_login_session_meta_user_id FOREIGN KEY (user_id) REFERENCES production."user" (user_id) ON DELETE SET NULL;