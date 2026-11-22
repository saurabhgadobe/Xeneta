SELECT
    TRY_CAST(DAY AS DATE) AS DAY,
    CURRENCY,
    TRY_CAST(RATE AS DECIMAL(18, 6)) AS RATE
FROM {{ source('raw', 'exchange_rates') }}
