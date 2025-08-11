----------------------------------------------------------------
--creating view for entity
----------------------------------------------------------------
CREATE OR REPLACE VIEW production.entity_meta_view
AS SELECT
      eMeta.entity_id,
      eMeta.label,
      eMeta.developer_name,
      eMeta.entity_type,
      eMeta.description,
      TO_CHAR(eMeta.last_modified_date AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Kolkata', 'YYYY-MM-DD HH24:MI:SS') AS "last_modified",
      TO_CHAR(eMeta.created_date AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Kolkata', 'YYYY-MM-DD HH24:MI:SS') AS "created_date",
      eMeta.package_name,
      eMeta.package_prefix
FROM production.entity_meta eMeta
WHERE entity_type = 'data'::text;