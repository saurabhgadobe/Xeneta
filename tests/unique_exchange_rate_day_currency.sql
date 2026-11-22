SELECT
    DAY,
    CURRENCY
FROM {{ source('raw', 'exchange_rates') }}
GROUP BY DAY, CURRENCY
HAVING COUNT(*) > 1
