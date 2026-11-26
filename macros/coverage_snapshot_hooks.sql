{% macro create_coverage_snapshot_table() %}
    CREATE TABLE IF NOT EXISTS final.coverage_snapshots (
        BATCH_ID VARCHAR PRIMARY KEY,
        DATAPOINTS_SOURCE_FILE VARCHAR,
        CHARGES_SOURCE_FILE VARCHAR,
        BEFORE_COVERED_LANES BIGINT NOT NULL,
        AFTER_COVERED_LANES BIGINT,
        DBT_INVOCATION_ID VARCHAR NOT NULL,
        CAPTURED_AT TIMESTAMPTZ NOT NULL,
        COMPLETED_AT TIMESTAMPTZ
    )
{% endmacro %}

{% macro capture_coverage_before() %}
    INSERT INTO final.coverage_snapshots (
        BATCH_ID,
        DATAPOINTS_SOURCE_FILE,
        CHARGES_SOURCE_FILE,
        BEFORE_COVERED_LANES,
        DBT_INVOCATION_ID,
        CAPTURED_AT
    )
    SELECT
        batches.BATCH_ID,
        MAX(CASE WHEN batches.TABLE_NAME = 'datapoints' THEN batches.SOURCE_FILE END),
        MAX(CASE WHEN batches.TABLE_NAME = 'charges' THEN batches.SOURCE_FILE END),
        COALESCE(
            (
                SELECT AFTER_COVERED_LANES
                FROM final.coverage_snapshots
                WHERE AFTER_COVERED_LANES IS NOT NULL
                ORDER BY COMPLETED_AT DESC
                LIMIT 1
            ),
            0
        ),
        '{{ invocation_id }}',
        CURRENT_TIMESTAMP
    FROM raw.load_batches AS batches
    WHERE batches.TABLE_NAME IN ('datapoints', 'charges')
      AND NOT EXISTS (
          SELECT 1
          FROM final.coverage_snapshots AS snapshots
          WHERE snapshots.BATCH_ID = batches.BATCH_ID
      )
    GROUP BY batches.BATCH_ID
{% endmacro %}

{% macro capture_coverage_after() %}
    UPDATE final.coverage_snapshots
    SET
        AFTER_COVERED_LANES = (
            SELECT COUNT(*)
            FROM final.aggregations
            WHERE dq_ok
        ),
        COMPLETED_AT = CURRENT_TIMESTAMP
    WHERE AFTER_COVERED_LANES IS NULL
{% endmacro %}
