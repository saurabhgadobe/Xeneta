{{ config(severity='warn') }}

SELECT
    D_ID,
    VALID_FROM,
    VALID_TO
FROM {{ source('raw', 'datapoints') }}
WHERE TRY_CAST(VALID_FROM AS DATE) > TRY_CAST(VALID_TO AS DATE)
