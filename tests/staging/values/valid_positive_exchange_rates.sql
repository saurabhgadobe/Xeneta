SELECT
    DAY,
    CURRENCY,
    RATE
FROM {{ ref('stg_exchange_rates') }}
WHERE RATE IS NULL
   OR RATE <= 0
