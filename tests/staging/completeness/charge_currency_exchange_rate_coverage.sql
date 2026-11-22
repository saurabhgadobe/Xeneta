WITH charge_periods AS (
    SELECT
        c.D_ID,
        c.CURRENCY,
        TRY_CAST(d.VALID_FROM AS DATE) AS VALID_FROM,
        TRY_CAST(d.VALID_TO AS DATE) AS VALID_TO
    FROM {{ source('raw', 'charges') }} AS c
    INNER JOIN {{ source('raw', 'datapoints') }} AS d
        ON c.D_ID = d.D_ID
),
charge_days AS (
    SELECT
        D_ID,
        CURRENCY,
        UNNEST(GENERATE_SERIES(VALID_FROM, VALID_TO, INTERVAL 1 DAY))::DATE AS DAY
    FROM charge_periods
)
SELECT
    cd.D_ID,
    cd.CURRENCY,
    cd.DAY
FROM charge_days AS cd
WHERE NOT EXISTS (
    SELECT 1
    FROM {{ source('raw', 'exchange_rates') }} AS er
    WHERE TRY_CAST(er.DAY AS DATE) = cd.DAY
      AND er.CURRENCY = cd.CURRENCY
)
