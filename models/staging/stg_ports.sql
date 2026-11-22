SELECT DISTINCT
    TRY_CAST(PID AS BIGINT) AS PID,
    CODE,
    SLUG,
    NAME,
    COUNTRY,
    COUNTRY_CODE
FROM {{ source('raw', 'ports') }}
