SELECT
    DAY,
    CURRENCY
FROM {{ ref('stg_exchange_rates') }}
GROUP BY DAY, CURRENCY
HAVING COUNT(*) > 1
