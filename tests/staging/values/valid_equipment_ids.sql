{{ config(severity='warn') }}

SELECT
    D_ID,
    EQUIPMENT_ID
FROM {{ source('raw', 'datapoints') }}
WHERE TRY_CAST(EQUIPMENT_ID AS INTEGER) IS NULL
   OR TRY_CAST(EQUIPMENT_ID AS INTEGER) NOT BETWEEN 1 AND 6
