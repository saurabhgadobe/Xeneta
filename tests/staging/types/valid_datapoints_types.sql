{{ config(severity='warn') }}

SELECT 'D_ID' AS column_name, D_ID AS invalid_value
FROM {{ source('raw', 'datapoints') }}
WHERE D_ID IS NOT NULL
  AND TRY_CAST(D_ID AS BIGINT) IS NULL

UNION ALL

SELECT 'CREATED' AS column_name, CREATED AS invalid_value
FROM {{ source('raw', 'datapoints') }}
WHERE CREATED IS NOT NULL
  AND TRY_CAST(CREATED AS TIMESTAMPTZ) IS NULL

UNION ALL

SELECT 'ORIGIN_PID' AS column_name, ORIGIN_PID AS invalid_value
FROM {{ source('raw', 'datapoints') }}
WHERE ORIGIN_PID IS NOT NULL
  AND TRY_CAST(ORIGIN_PID AS BIGINT) IS NULL

UNION ALL

SELECT 'DESTINATION_PID' AS column_name, DESTINATION_PID AS invalid_value
FROM {{ source('raw', 'datapoints') }}
WHERE DESTINATION_PID IS NOT NULL
  AND TRY_CAST(DESTINATION_PID AS BIGINT) IS NULL

UNION ALL

SELECT 'VALID_FROM' AS column_name, VALID_FROM AS invalid_value
FROM {{ source('raw', 'datapoints') }}
WHERE VALID_FROM IS NOT NULL
  AND TRY_CAST(VALID_FROM AS DATE) IS NULL

UNION ALL

SELECT 'VALID_TO' AS column_name, VALID_TO AS invalid_value
FROM {{ source('raw', 'datapoints') }}
WHERE VALID_TO IS NOT NULL
  AND TRY_CAST(VALID_TO AS DATE) IS NULL

UNION ALL

SELECT 'COMPANY_ID' AS column_name, COMPANY_ID AS invalid_value
FROM {{ source('raw', 'datapoints') }}
WHERE COMPANY_ID IS NOT NULL
  AND TRY_CAST(COMPANY_ID AS BIGINT) IS NULL

UNION ALL

SELECT 'SUPPLIER_ID' AS column_name, SUPPLIER_ID AS invalid_value
FROM {{ source('raw', 'datapoints') }}
WHERE SUPPLIER_ID IS NOT NULL
  AND TRY_CAST(SUPPLIER_ID AS BIGINT) IS NULL

UNION ALL

SELECT 'EQUIPMENT_ID' AS column_name, EQUIPMENT_ID AS invalid_value
FROM {{ source('raw', 'datapoints') }}
WHERE EQUIPMENT_ID IS NOT NULL
  AND TRY_CAST(EQUIPMENT_ID AS INTEGER) IS NULL
