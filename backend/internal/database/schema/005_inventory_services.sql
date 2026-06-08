-- Allow service lines in inventory documents

ALTER TABLE inventory_document_lines
  ALTER COLUMN product_id DROP NOT NULL;

ALTER TABLE inventory_document_lines
  ADD COLUMN IF NOT EXISTS service_id UUID REFERENCES services(id) ON DELETE RESTRICT;

ALTER TABLE inventory_document_lines
  DROP CONSTRAINT IF EXISTS inventory_lines_item_required_chk;

ALTER TABLE inventory_document_lines
  ADD CONSTRAINT inventory_lines_item_required_chk
  CHECK (product_id IS NOT NULL OR service_id IS NOT NULL);

CREATE INDEX IF NOT EXISTS inventory_document_lines_service_id_idx
  ON inventory_document_lines (service_id)
  WHERE service_id IS NOT NULL;
