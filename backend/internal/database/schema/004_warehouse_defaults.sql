ALTER TABLE warehouses
ADD COLUMN IF NOT EXISTS is_default BOOLEAN NOT NULL DEFAULT FALSE;

WITH ranked_warehouses AS (
  SELECT
    id,
    company_id,
    ROW_NUMBER() OVER (
      PARTITION BY company_id
      ORDER BY created_at ASC, id ASC
    ) AS position
  FROM warehouses
  WHERE archived_at IS NULL
)
UPDATE warehouses w
SET is_default = ranked_warehouses.position = 1
FROM ranked_warehouses
WHERE ranked_warehouses.id = w.id;
