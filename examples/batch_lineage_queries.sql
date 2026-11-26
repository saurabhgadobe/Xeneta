-- Files loaded for each batch, with row counts and load timestamps.
SELECT
    BATCH_ID,
    TABLE_NAME,
    SOURCE_FILE,
    ROW_COUNT,
    LOADED_AT
FROM raw.load_batches
ORDER BY LOADED_AT, BATCH_ID, TABLE_NAME;

-- Covered lane counts before and after each batch, including the change.
SELECT
    BATCH_ID,
    DATAPOINTS_SOURCE_FILE,
    CHARGES_SOURCE_FILE,
    BEFORE_COVERED_LANES,
    AFTER_COVERED_LANES,
    AFTER_COVERED_LANES - BEFORE_COVERED_LANES AS COVERED_LANE_CHANGE,
    CAPTURED_AT,
    COMPLETED_AT
FROM final.coverage_snapshots
ORDER BY COMPLETED_AT, BATCH_ID;

-- Daily prices attributed to a datapoint batch and the charge files used.
SELECT
    DATAPOINTS_BATCH_ID,
    DATAPOINTS_SOURCE_FILE,
    CHARGES_BATCH_IDS,
    CHARGES_SOURCE_FILES,
    COUNT(DISTINCT D_ID) AS datapoint_count,
    COUNT(*) AS daily_price_rows,
    MIN(INGESTED_AT) AS first_price_ingestion_at,
    MAX(INGESTED_AT) AS latest_price_ingestion_at
FROM final.prices
WHERE DATAPOINTS_BATCH_ID = 'batch_2'
GROUP BY
    DATAPOINTS_BATCH_ID,
    DATAPOINTS_SOURCE_FILE,
    CHARGES_BATCH_IDS,
    CHARGES_SOURCE_FILES;

-- Raw charge rows from one source file.
SELECT
    D_ID,
    CURRENCY,
    CHARGE_VALUE,
    BATCH_ID,
    SOURCE_FILE,
    INGESTED_AT
FROM raw.charges
WHERE BATCH_ID = 'batch_2'
ORDER BY D_ID;

-- Charge rows currently waiting for a matching datapoint row to arrive.
SELECT
    c.BATCH_ID,
    c.SOURCE_FILE,
    COUNT(*) AS pending_charge_rows,
    COUNT(DISTINCT c.D_ID) AS pending_datapoints
FROM raw.charges AS c
WHERE NOT EXISTS (
    SELECT 1
    FROM raw.datapoints AS d
    WHERE d.D_ID = c.D_ID
)
GROUP BY c.BATCH_ID, c.SOURCE_FILE
ORDER BY c.BATCH_ID, c.SOURCE_FILE;
