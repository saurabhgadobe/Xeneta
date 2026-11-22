SELECT 'PID' AS column_name, PID AS invalid_value
FROM {{ source('raw', 'ports') }}
WHERE PID IS NOT NULL
  AND TRY_CAST(PID AS BIGINT) IS NULL
