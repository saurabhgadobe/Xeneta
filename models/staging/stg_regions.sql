WITH source_regions AS (
    SELECT DISTINCT
        SLUG,
        NAME,
        NULLIF(PARENT, '') AS PARENT,
        INGESTED_AT
    FROM {{ source('raw', 'regions') }}
    WHERE SLUG IS NOT NULL
      AND TRIM(SLUG) <> ''
),
unique_regions AS (
    SELECT SLUG, NAME, PARENT, INGESTED_AT
    FROM source_regions AS r
    WHERE (
        SELECT COUNT(*)
        FROM source_regions AS other
        WHERE other.SLUG = r.SLUG
    ) = 1
)
SELECT
    r.SLUG,
    r.NAME,
    r.PARENT,
    r.INGESTED_AT
FROM unique_regions AS r
WHERE r.PARENT IS NULL
   OR EXISTS (
        SELECT 1
        FROM unique_regions AS parent_region
        WHERE parent_region.SLUG = r.PARENT
   )
