-- Recipes (технологические карты производства)
CREATE TABLE IF NOT EXISTS recipes (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id  UUID        NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  name        TEXT        NOT NULL CHECK (length(name) BETWEEN 2 AND 200),
  description TEXT        NOT NULL DEFAULT '',
  is_active   BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  archived_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS recipes_company_id ON recipes(company_id)
  WHERE archived_at IS NULL;

-- Входящие товары рецепта
CREATE TABLE IF NOT EXISTS recipe_ingredients (
  id         UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  recipe_id  UUID          NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
  product_id UUID          NOT NULL REFERENCES products(id),
  quantity   NUMERIC(18,3) NOT NULL DEFAULT 1 CHECK (quantity > 0),
  unit_name  TEXT          NOT NULL DEFAULT 'шт',
  created_at TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS recipe_ingredients_recipe_id ON recipe_ingredients(recipe_id);

-- Входящие услуги рецепта
CREATE TABLE IF NOT EXISTS recipe_services (
  id         UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  recipe_id  UUID          NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
  service_id UUID          NOT NULL REFERENCES services(id),
  quantity   NUMERIC(18,3) NOT NULL DEFAULT 1 CHECK (quantity > 0),
  created_at TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS recipe_services_recipe_id ON recipe_services(recipe_id);

-- Выход готовой продукции рецепта
CREATE TABLE IF NOT EXISTS recipe_outputs (
  id         UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  recipe_id  UUID          NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
  product_id UUID          NOT NULL REFERENCES products(id),
  quantity   NUMERIC(18,3) NOT NULL DEFAULT 1 CHECK (quantity > 0),
  unit_name  TEXT          NOT NULL DEFAULT 'шт',
  created_at TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS recipe_outputs_recipe_id ON recipe_outputs(recipe_id);

-- Производственные документы
CREATE TABLE IF NOT EXISTS production_orders (
  id                   UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id           UUID          NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  document_no          TEXT          NOT NULL,
  recipe_id            UUID          REFERENCES recipes(id),
  source_warehouse_id  UUID          REFERENCES warehouses(id),
  output_warehouse_id  UUID          REFERENCES warehouses(id),
  batch_number         TEXT          NOT NULL DEFAULT '',
  responsible_employee TEXT          NOT NULL DEFAULT '',
  planned_quantity     NUMERIC(18,3) NOT NULL DEFAULT 1 CHECK (planned_quantity > 0),
  status               TEXT          NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'in_progress', 'completed', 'cancelled')),
  planned_date         DATE,
  notes                TEXT          NOT NULL DEFAULT '',
  created_by_user_id   TEXT          REFERENCES users(id) ON DELETE SET NULL,
  created_at           TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS production_orders_company_id
  ON production_orders(company_id, created_at DESC);

CREATE UNIQUE INDEX IF NOT EXISTS production_orders_company_doc_no_uq
  ON production_orders(company_id, lower(document_no));

DROP TRIGGER IF EXISTS trg_recipes_set_updated_at ON recipes;
CREATE TRIGGER trg_recipes_set_updated_at
BEFORE UPDATE ON recipes
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_production_orders_set_updated_at ON production_orders;
CREATE TRIGGER trg_production_orders_set_updated_at
BEFORE UPDATE ON production_orders
FOR EACH ROW EXECUTE FUNCTION set_updated_at();
