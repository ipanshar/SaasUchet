-- Extend products with type and sale permission
ALTER TABLE products
  ADD COLUMN IF NOT EXISTS product_type TEXT NOT NULL DEFAULT 'consumer_goods'
    CHECK (product_type IN ('raw_material', 'finished_product', 'consumer_goods')),
  ADD COLUMN IF NOT EXISTS allowed_to_sell BOOLEAN NOT NULL DEFAULT TRUE;

-- Services catalog
CREATE TABLE IF NOT EXISTS services (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id      UUID        NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  name            TEXT        NOT NULL CHECK (length(name) BETWEEN 2 AND 200),
  description     TEXT        NOT NULL DEFAULT '',
  price           NUMERIC(18,2) NOT NULL DEFAULT 0 CHECK (price >= 0),
  allowed_to_sell BOOLEAN     NOT NULL DEFAULT TRUE,
  is_active       BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  archived_at     TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS services_company_id ON services(company_id)
  WHERE archived_at IS NULL;

-- Service components: products, sub-services, external contractor services
CREATE TABLE IF NOT EXISTS service_materials (
  id                    UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  service_id            UUID         NOT NULL REFERENCES services(id) ON DELETE CASCADE,
  material_type         TEXT         NOT NULL
    CHECK (material_type IN ('product', 'sub_service', 'external_service')),
  product_id            UUID         REFERENCES products(id),
  sub_service_id        UUID         REFERENCES services(id),
  external_service_name TEXT         NOT NULL DEFAULT '',
  quantity              NUMERIC(18,3) NOT NULL DEFAULT 1 CHECK (quantity > 0),
  cost                  NUMERIC(18,2) NOT NULL DEFAULT 0 CHECK (cost >= 0),
  created_at            TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS service_materials_service_id ON service_materials(service_id);
