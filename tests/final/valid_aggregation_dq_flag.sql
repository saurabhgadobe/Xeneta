SELECT
    DAY,
    EQUIPMENT_ID,
    origin_type,
    origin_id,
    destination_type,
    destination_id,
    company_count,
    supplier_count,
    dq_ok
FROM {{ ref('aggregations') }}
WHERE dq_ok IS DISTINCT FROM (
    company_count >= {{ var('coverage_min_companies', 5) }}
    AND supplier_count >= {{ var('coverage_min_suppliers', 2) }}
)
