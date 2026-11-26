-- 1. Daily average and median for one region-to-region lane.
SELECT
    DAY,
    average_price_usd,
    median_price_usd,
    company_count,
    supplier_count,
    dq_ok
FROM final.aggregations
WHERE EQUIPMENT_ID = 2
  AND origin_type = 'REGION'
  AND origin_name = 'China East Main'
  AND destination_type = 'REGION'
  AND destination_name = 'US West Coast'
ORDER BY DAY;

-- 2. Daily average and median for one port-to-port lane.
-- Port names are used here for readability; port IDs are also available.
SELECT
    DAY,
    average_price_usd,
    median_price_usd
FROM final.aggregations
WHERE EQUIPMENT_ID = 2
  AND origin_type = 'PORT'
  AND origin_name = 'Shanghai'
  AND destination_type = 'PORT'
  AND destination_name = 'Oakland, CA'
ORDER BY DAY;

-- 3. Find covered destination regions from a selected origin region
--    for one equipment type and day.
SELECT
    destination_id,
    destination_name,
    average_price_usd,
    median_price_usd,
    company_count,
    supplier_count
FROM final.aggregations
WHERE DAY = DATE '2021-06-01'
  AND EQUIPMENT_ID = 2
  AND origin_type = 'REGION'
  AND origin_name = 'China East Main'
  AND destination_type = 'REGION'
  AND dq_ok
ORDER BY average_price_usd;

-- 4. Show only end-user-ready results for a particular lane and date range.
SELECT
    DAY,
    average_price_usd,
    median_price_usd
FROM final.aggregations
WHERE EQUIPMENT_ID = 2
  AND origin_type = 'REGION'
  AND origin_name = 'China East Main'
  AND destination_type = 'REGION'
  AND destination_name = 'US West Coast'
  AND DAY BETWEEN DATE '2021-01-01' AND DATE '2021-06-30'
  AND dq_ok
ORDER BY DAY;

-- 5. Compare both directions. These remain separate rows because origin and
--    destination are directional parts of the lane key.
SELECT
    DAY,
    origin_name,
    destination_name,
    average_price_usd,
    median_price_usd,
    dq_ok
FROM final.aggregations
WHERE DAY = DATE '2021-06-01'
  AND EQUIPMENT_ID = 2
  AND origin_type = 'REGION'
  AND destination_type = 'REGION'
  AND (
      (origin_name = 'China East Main' AND destination_name = 'US West Coast')
      OR (origin_name = 'US West Coast' AND destination_name = 'China East Main')
  )
ORDER BY DAY;
