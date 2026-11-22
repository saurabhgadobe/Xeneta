SELECT
    SLUG,
    NAME,
    NULLIF(PARENT, '') AS PARENT
FROM {{ source('raw', 'regions') }}
