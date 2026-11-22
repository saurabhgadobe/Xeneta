SELECT 'D_ID' AS column_name, D_ID AS invalid_value
FROM {{ source('raw', 'charges') }}
WHERE D_ID IS NOT NULL
  AND TRY_CAST(D_ID AS BIGINT) IS NULL

UNION ALL

SELECT 'CHARGE_VALUE' AS column_name, CHARGE_VALUE AS invalid_value
FROM {{ source('raw', 'charges') }}
WHERE CHARGE_VALUE IS NOT NULL
  AND TRY_CAST(CHARGE_VALUE AS DECIMAL(18, 6)) IS NULL
