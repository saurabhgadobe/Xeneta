{{ config(
    materialized='table',
    pre_hook=[
        create_coverage_snapshot_table(),
        capture_coverage_before()
    ],
    post_hook=capture_coverage_after()
) }}

WITH RECURSIVE region_ancestors (leaf_slug, ancestor_slug) AS (
    SELECT
        SLUG AS leaf_slug,
        SLUG AS ancestor_slug
    FROM {{ ref('stg_regions') }}

    UNION ALL

    SELECT
        ra.leaf_slug,
        current_region.PARENT AS ancestor_slug
    FROM region_ancestors AS ra
    INNER JOIN {{ ref('stg_regions') }} AS current_region
        ON ra.ancestor_slug = current_region.SLUG
    WHERE current_region.PARENT IS NOT NULL
),
port_location_memberships AS (
    SELECT
        p.PID,
        'PORT' AS location_type,
        CAST(p.PID AS VARCHAR) AS location_id,
        p.NAME AS location_name
    FROM {{ ref('stg_ports') }} AS p

    UNION ALL

    SELECT
        p.PID,
        'REGION' AS location_type,
        r.SLUG AS location_id,
        r.NAME AS location_name
    FROM {{ ref('stg_ports') }} AS p
    INNER JOIN region_ancestors AS ra
        ON p.SLUG = ra.leaf_slug
    INNER JOIN {{ ref('stg_regions') }} AS r
        ON ra.ancestor_slug = r.SLUG
),
lane_prices AS (
    SELECT
        p.DAY,
        p.EQUIPMENT_ID,
        origin.location_type AS origin_type,
        origin.location_id AS origin_id,
        origin.location_name AS origin_name,
        destination.location_type AS destination_type,
        destination.location_id AS destination_id,
        destination.location_name AS destination_name,
        p.D_ID,
        p.COMPANY_ID,
        p.SUPPLIER_ID,
        p.INGESTED_AT,
        p.PRICE_USD
    FROM {{ ref('prices') }} AS p
    INNER JOIN port_location_memberships AS origin
        ON p.ORIGIN_PID = origin.PID
    INNER JOIN port_location_memberships AS destination
        ON p.DESTINATION_PID = destination.PID
),
lane_aggregates AS (
    SELECT
        DAY,
        EQUIPMENT_ID,
        origin_type,
        origin_id,
        origin_name,
        destination_type,
        destination_id,
        destination_name,
        AVG(PRICE_USD) AS average_price_usd,
        MEDIAN(PRICE_USD) AS median_price_usd,
        COUNT(DISTINCT COMPANY_ID) AS company_count,
        COUNT(DISTINCT SUPPLIER_ID) AS supplier_count,
        MAX(INGESTED_AT) AS INGESTED_AT
    FROM lane_prices
    GROUP BY
        DAY,
        EQUIPMENT_ID,
        origin_type,
        origin_id,
        origin_name,
        destination_type,
        destination_id,
        destination_name
)
SELECT
    DAY,
    EQUIPMENT_ID,
    origin_type,
    origin_id,
    origin_name,
    destination_type,
    destination_id,
    destination_name,
    CAST(average_price_usd AS DECIMAL(18, 6)) AS average_price_usd,
    CAST(median_price_usd AS DECIMAL(18, 6)) AS median_price_usd,
    company_count,
    supplier_count,
    INGESTED_AT,
    company_count >= {{ var('coverage_min_companies', 5) }}
        AND supplier_count >= {{ var('coverage_min_suppliers', 2) }} AS dq_ok
FROM lane_aggregates
