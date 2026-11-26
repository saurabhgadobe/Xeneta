WITH typed_ports AS (
    SELECT DISTINCT
        TRY_CAST(PID AS BIGINT) AS PID,
        CODE,
        SLUG,
        NAME,
        COUNTRY,
        COUNTRY_CODE,
        BATCH_ID,
        SOURCE_FILE,
        INGESTED_AT
    FROM {{ source('raw', 'ports') }}
    WHERE TRY_CAST(PID AS BIGINT) IS NOT NULL
      AND CODE IS NOT NULL
      AND TRIM(CODE) <> ''
      AND SLUG IS NOT NULL
      AND TRIM(SLUG) <> ''
),
unique_ports AS (
    SELECT p.*
    FROM typed_ports AS p
    WHERE (
        SELECT COUNT(*)
        FROM typed_ports AS same_pid
        WHERE same_pid.PID = p.PID
    ) = 1
      AND (
        SELECT COUNT(*)
        FROM typed_ports AS same_code
        WHERE same_code.CODE = p.CODE
    ) = 1
)
SELECT p.*
FROM unique_ports AS p
INNER JOIN {{ ref('stg_regions') }} AS r
    ON p.SLUG = r.SLUG
