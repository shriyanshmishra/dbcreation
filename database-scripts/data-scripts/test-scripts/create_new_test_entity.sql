SELECT production.create_data_table_and_share_table_function(
'{
    "data_space": "production",
    "meta_table": "entity_meta",
    "active_session": {
        "session_token": "Default-session-for-testing"
    },
    "data": [
        {
            "data_space": "production",
            "label": "Account",
            "plural_label" : "Accounts",
            "developer_name" : "account",
            "prefix": "A01",
            "track_field_history" : false,
            "allow_reports": false,
            "allow_activities": false,
            "allow_sharing": false,
            "in_development": false,
            "deployed": false
        },
        {
			"data_space": "production",
            "label": "Contact",
            "plural_label" : "Contacts",
            "developer_name" : "contact",
            "prefix": "A02",
            "track_field_history" : false,
            "allow_reports": false,
            "allow_activities": false,
            "allow_sharing": false,
            "in_development": false,
            "deployed": false
        }
    ]
}'::jsonb
);

