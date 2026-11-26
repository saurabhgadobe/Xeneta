{{ config(
    materialized='incremental',
    incremental_strategy='append'
) }}

WITH typed_datapoints AS (
    SELECT
        TRY_CAST(D_ID AS BIGINT) AS D_ID,
        TRY_CAST(CREATED AS TIMESTAMPTZ) AS CREATED,
        TRY_CAST(ORIGIN_PID AS BIGINT) AS ORIGIN_PID,
        TRY_CAST(DESTINATION_PID AS BIGINT) AS DESTINATION_PID,
        TRY_CAST(VALID_FROM AS DATE) AS VALID_FROM,
        TRY_CAST(VALID_TO AS DATE) AS VALID_TO,
        TRY_CAST(COMPANY_ID AS BIGINT) AS COMPANY_ID,
        TRY_CAST(SUPPLIER_ID AS BIGINT) AS SUPPLIER_ID,
        TRY_CAST(EQUIPMENT_ID AS INTEGER) AS         EQUIPMENT_ID,
        BATCH_ID,
        SOURCE_FILE,
        INGESTED_AT
    FROM {{ source('raw', 'datapoints') }}
    {% if is_incremental() %}
    WHERE TRY_CAST(D_ID AS BIGINT) NOT IN (
        SELECT D_ID FROM {{ this }}
    )
    {% endif %}
),
valid_datapoints AS (
    SELECT *
    FROM typed_datapoints
    WHERE D_ID IS NOT NULL
      AND ORIGIN_PID IS NOT NULL
      AND DESTINATION_PID IS NOT NULL
      AND COMPANY_ID IS NOT NULL
      AND SUPPLIER_ID IS NOT NULL
      AND EQUIPMENT_ID BETWEEN 1 AND 6
      AND VALID_FROM IS NOT NULL
      AND VALID_TO IS NOT NULL
      AND VALID_FROM <= VALID_TO
      AND VALID_FROM >= DATE '2021-01-01'
      AND VALID_TO <= DATE '2022-06-01'
      AND NOT EXISTS (
          SELECT 1
          FROM {{ source('raw', 'datapoints') }} AS raw_dp
          WHERE TRY_CAST(raw_dp.D_ID AS BIGINT) = typed_datapoints.D_ID
            AND (
                (raw_dp.CREATED IS NOT NULL AND TRY_CAST(raw_dp.CREATED AS TIMESTAMPTZ) IS NULL)
                OR (raw_dp.COMPANY_ID IS NOT NULL AND TRY_CAST(raw_dp.COMPANY_ID AS BIGINT) IS NULL)
                OR (raw_dp.SUPPLIER_ID IS NOT NULL AND TRY_CAST(raw_dp.SUPPLIER_ID AS BIGINT) IS NULL)
                OR (raw_dp.EQUIPMENT_ID IS NOT NULL AND TRY_CAST(raw_dp.EQUIPMENT_ID AS INTEGER) IS NULL)
            )
      )
)
SELECT d.*
FROM valid_datapoints AS d
INNER JOIN {{ ref('stg_ports') }} AS origin
    ON d.ORIGIN_PID = origin.PID
INNER JOIN {{ ref('stg_ports') }} AS destination
    ON d.DESTINATION_PID = destination.PID
WHERE (
    SELECT COUNT(*)
    FROM typed_datapoints AS same_id
    WHERE same_id.D_ID = d.D_ID
) = 1
