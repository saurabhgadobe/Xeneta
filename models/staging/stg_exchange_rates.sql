WITH typed_rates AS (
    SELECT
        TRY_CAST(DAY AS DATE) AS DAY,
        CURRENCY,
        TRY_CAST(RATE AS DECIMAL(18, 6)) AS RATE,
        BATCH_ID,
        SOURCE_FILE,
        INGESTED_AT
    FROM {{ source('raw', 'exchange_rates') }}
    WHERE TRY_CAST(DAY AS DATE) IS NOT NULL
      AND CURRENCY IS NOT NULL
      AND TRIM(CURRENCY) <> ''
      AND TRY_CAST(RATE AS DECIMAL(18, 6)) > 0
)
SELECT DAY, CURRENCY, RATE, BATCH_ID, SOURCE_FILE, INGESTED_AT
FROM typed_rates AS r
WHERE (
    SELECT COUNT(*)
    FROM typed_rates AS same_rate
    WHERE same_rate.DAY = r.DAY
      AND same_rate.CURRENCY = r.CURRENCY
) = 1
