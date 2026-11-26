{{ config(severity='warn') }}

SELECT
    child.SLUG,
    child.PARENT
FROM {{ source('raw', 'regions') }} AS child
WHERE NULLIF(TRIM(child.PARENT), '') IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM {{ source('raw', 'regions') }} AS parent
      WHERE parent.SLUG = child.PARENT
  )
