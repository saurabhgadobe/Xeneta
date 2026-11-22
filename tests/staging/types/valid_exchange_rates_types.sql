SELECT 'DAY' AS column_name, DAY AS invalid_value
FROM {{ source('raw', 'exchange_rates') }}
WHERE DAY IS NOT NULL
  AND TRY_CAST(DAY AS DATE) IS NULL

UNION ALL

SELECT 'RATE' AS column_name, RATE AS invalid_value
FROM {{ source('raw', 'exchange_rates') }}
WHERE RATE IS NOT NULL
  AND TRY_CAST(RATE AS DOUBLE) IS NULL
