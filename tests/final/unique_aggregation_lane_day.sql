SELECT
    DAY,
    EQUIPMENT_ID,
    origin_type,
    origin_id,
    destination_type,
    destination_id
FROM {{ ref('aggregations') }}
GROUP BY
    DAY,
    EQUIPMENT_ID,
    origin_type,
    origin_id,
    destination_type,
    destination_id
HAVING COUNT(*) > 1
