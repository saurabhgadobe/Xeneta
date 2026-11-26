SELECT 'ports' AS table_name, r.BATCH_ID, r.SOURCE_FILE
FROM {{ source('raw', 'ports') }} AS r
WHERE r.BATCH_ID IS NULL
   OR r.SOURCE_FILE IS NULL
   OR r.INGESTED_AT IS NULL
   OR NOT EXISTS (
       SELECT 1
       FROM raw.load_batches AS batches
       WHERE batches.BATCH_ID = r.BATCH_ID
         AND batches.TABLE_NAME = 'ports'
         AND batches.SOURCE_FILE = r.SOURCE_FILE
   )

UNION ALL

SELECT 'regions', r.BATCH_ID, r.SOURCE_FILE
FROM {{ source('raw', 'regions') }} AS r
WHERE r.BATCH_ID IS NULL
   OR r.SOURCE_FILE IS NULL
   OR r.INGESTED_AT IS NULL
   OR NOT EXISTS (
       SELECT 1
       FROM raw.load_batches AS batches
       WHERE batches.BATCH_ID = r.BATCH_ID
         AND batches.TABLE_NAME = 'regions'
         AND batches.SOURCE_FILE = r.SOURCE_FILE
   )

UNION ALL

SELECT 'exchange_rates', r.BATCH_ID, r.SOURCE_FILE
FROM {{ source('raw', 'exchange_rates') }} AS r
WHERE r.BATCH_ID IS NULL
   OR r.SOURCE_FILE IS NULL
   OR r.INGESTED_AT IS NULL
   OR NOT EXISTS (
       SELECT 1
       FROM raw.load_batches AS batches
       WHERE batches.BATCH_ID = r.BATCH_ID
         AND batches.TABLE_NAME = 'exchange_rates'
         AND batches.SOURCE_FILE = r.SOURCE_FILE
   )

UNION ALL

SELECT 'datapoints', r.BATCH_ID, r.SOURCE_FILE
FROM {{ source('raw', 'datapoints') }} AS r
WHERE r.BATCH_ID IS NULL
   OR r.SOURCE_FILE IS NULL
   OR r.INGESTED_AT IS NULL
   OR NOT EXISTS (
       SELECT 1
       FROM raw.load_batches AS batches
       WHERE batches.BATCH_ID = r.BATCH_ID
         AND batches.TABLE_NAME = 'datapoints'
         AND batches.SOURCE_FILE = r.SOURCE_FILE
   )

UNION ALL

SELECT 'charges', r.BATCH_ID, r.SOURCE_FILE
FROM {{ source('raw', 'charges') }} AS r
WHERE r.BATCH_ID IS NULL
   OR r.SOURCE_FILE IS NULL
   OR r.INGESTED_AT IS NULL
   OR NOT EXISTS (
       SELECT 1
       FROM raw.load_batches AS batches
       WHERE batches.BATCH_ID = r.BATCH_ID
         AND batches.TABLE_NAME = 'charges'
         AND batches.SOURCE_FILE = r.SOURCE_FILE
   )
