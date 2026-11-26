{{ config(materialized='table') }}

WITH source_charges AS (
    SELECT
        TRY_CAST(D_ID AS BIGINT) AS D_ID,
        CURRENCY,
        TRY_CAST(CHARGE_VALUE AS DECIMAL(18, 6)) AS CHARGE_VALUE,
        BATCH_ID,
        SOURCE_FILE,
        INGESTED_AT
    FROM {{ source('raw', 'charges') }}
),
invalid_charge_datapoints AS (
    SELECT DISTINCT c.D_ID, c.BATCH_ID
    FROM source_charges AS c
    INNER JOIN {{ ref('stg_datapoints') }} AS d
        ON c.D_ID = d.D_ID
    WHERE c.CURRENCY IS NULL
       OR TRIM(c.CURRENCY) = ''
       OR c.CHARGE_VALUE IS NULL
),
contract_days AS (
    SELECT
        D_ID,
        BATCH_ID,
        UNNEST(GENERATE_SERIES(VALID_FROM, VALID_TO, INTERVAL 1 DAY))::DATE AS DAY
    FROM {{ ref('stg_datapoints') }}
),
missing_rate_datapoints AS (
    SELECT DISTINCT c.D_ID, c.BATCH_ID
    FROM source_charges AS c
    INNER JOIN contract_days AS cd
        ON c.D_ID = cd.D_ID
    LEFT JOIN {{ ref('stg_exchange_rates') }} AS er
        ON cd.DAY = er.DAY
       AND c.CURRENCY = er.CURRENCY
    WHERE c.CURRENCY IS NULL
       OR TRIM(c.CURRENCY) = ''
       OR er.DAY IS NULL
),
excluded_datapoints AS (
    SELECT DISTINCT D_ID FROM invalid_charge_datapoints
    UNION
    SELECT DISTINCT D_ID FROM missing_rate_datapoints
),
eligible_datapoints AS (
    SELECT DISTINCT d.D_ID
    FROM {{ ref('stg_datapoints') }} AS d
    LEFT JOIN excluded_datapoints AS excluded
        ON d.D_ID = excluded.D_ID
    WHERE excluded.D_ID IS NULL
)
SELECT
    c.D_ID,
    c.CURRENCY,
    c.CHARGE_VALUE,
    c.BATCH_ID,
    c.SOURCE_FILE,
    c.INGESTED_AT
FROM source_charges AS c
INNER JOIN eligible_datapoints AS eligible
    ON c.D_ID = eligible.D_ID
