SELECT c.D_ID, c.BATCH_ID, c.SOURCE_FILE
FROM {{ ref('stg_charges') }} AS c
WHERE c.BATCH_ID IS NULL
   OR c.SOURCE_FILE IS NULL
   OR NOT EXISTS (
       SELECT 1
       FROM raw.load_batches AS batches
       WHERE batches.BATCH_ID = c.BATCH_ID
         AND batches.TABLE_NAME = 'charges'
         AND batches.SOURCE_FILE = c.SOURCE_FILE
   )
