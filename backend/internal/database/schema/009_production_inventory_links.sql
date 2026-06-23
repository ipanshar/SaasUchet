ALTER TABLE production_orders
  ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ;

ALTER TABLE production_orders
  ADD COLUMN IF NOT EXISTS production_out_document_id UUID REFERENCES inventory_documents(id) ON DELETE SET NULL;

ALTER TABLE production_orders
  ADD COLUMN IF NOT EXISTS production_in_document_id UUID REFERENCES inventory_documents(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS production_orders_inventory_documents_idx
  ON production_orders (production_out_document_id, production_in_document_id)
  WHERE production_out_document_id IS NOT NULL
     OR production_in_document_id IS NOT NULL;
