CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Companies and access model
CREATE TABLE IF NOT EXISTS companies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  name TEXT NOT NULL,
  legal_form TEXT,
  country_code CHAR(2) NOT NULL DEFAULT 'KZ',
  tax_identifier TEXT,
  registration_number TEXT,
  email TEXT,
  phone TEXT,
  address_line TEXT,
  city TEXT,
  region TEXT,
  postal_code TEXT,
  currency_code CHAR(3) NOT NULL DEFAULT 'KZT',
  timezone_name TEXT NOT NULL DEFAULT 'Asia/Almaty',
  is_vat_payer BOOLEAN NOT NULL DEFAULT FALSE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  archived_at TIMESTAMPTZ,
  CONSTRAINT companies_name_length_chk CHECK (char_length(name) BETWEEN 2 AND 160),
  CONSTRAINT companies_country_code_chk CHECK (country_code ~ '^[A-Z]{2}$'),
  CONSTRAINT companies_currency_code_chk CHECK (currency_code ~ '^[A-Z]{3}$')
);

CREATE INDEX IF NOT EXISTS companies_owner_user_id_idx
  ON companies (owner_user_id);

CREATE UNIQUE INDEX IF NOT EXISTS companies_owner_name_uq
  ON companies (owner_user_id, lower(name))
  WHERE archived_at IS NULL;

CREATE TABLE IF NOT EXISTS company_memberships (
  company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'staff',
  is_default_company BOOLEAN NOT NULL DEFAULT FALSE,
  invited_at TIMESTAMPTZ,
  accepted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (company_id, user_id),
  CONSTRAINT company_memberships_role_chk CHECK (
    role IN ('owner', 'admin', 'manager', 'accountant', 'warehouse', 'sales', 'staff')
  )
);

CREATE INDEX IF NOT EXISTS company_memberships_user_id_idx
  ON company_memberships (user_id);

CREATE UNIQUE INDEX IF NOT EXISTS company_memberships_default_company_uq
  ON company_memberships (user_id)
  WHERE is_default_company = TRUE;

-- CRM
CREATE TABLE IF NOT EXISTS clients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  code TEXT,
  client_kind TEXT NOT NULL DEFAULT 'company',
  name TEXT NOT NULL,
  contact_name TEXT,
  phone TEXT,
  email TEXT,
  bin TEXT,
  iin TEXT,
  country_code CHAR(2) NOT NULL DEFAULT 'KZ',
  segment TEXT NOT NULL DEFAULT 'regular',
  status TEXT NOT NULL DEFAULT 'active',
  credit_limit NUMERIC(18, 2) NOT NULL DEFAULT 0,
  payment_term_days INTEGER NOT NULL DEFAULT 0,
  notes TEXT,
  created_by_user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
  updated_by_user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  archived_at TIMESTAMPTZ,
  CONSTRAINT clients_kind_chk CHECK (client_kind IN ('company', 'person')),
  CONSTRAINT clients_segment_chk CHECK (segment IN ('lead', 'regular', 'vip', 'blocked')),
  CONSTRAINT clients_status_chk CHECK (status IN ('active', 'inactive', 'archived')),
  CONSTRAINT clients_country_code_chk CHECK (country_code ~ '^[A-Z]{2}$'),
  CONSTRAINT clients_bin_chk CHECK (bin IS NULL OR bin ~ '^[0-9]{12}$'),
  CONSTRAINT clients_iin_chk CHECK (iin IS NULL OR iin ~ '^[0-9]{12}$'),
  CONSTRAINT clients_name_length_chk CHECK (char_length(name) BETWEEN 2 AND 160)
);

CREATE INDEX IF NOT EXISTS clients_company_id_idx
  ON clients (company_id);

CREATE INDEX IF NOT EXISTS clients_company_segment_idx
  ON clients (company_id, segment)
  WHERE archived_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS clients_company_code_uq
  ON clients (company_id, lower(code))
  WHERE code IS NOT NULL AND archived_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS clients_company_bin_uq
  ON clients (company_id, bin)
  WHERE bin IS NOT NULL AND archived_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS clients_company_iin_uq
  ON clients (company_id, iin)
  WHERE iin IS NOT NULL AND archived_at IS NULL;

CREATE TABLE IF NOT EXISTS client_interactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  client_id UUID NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
  interaction_type TEXT NOT NULL,
  subject TEXT NOT NULL,
  note TEXT,
  happened_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  next_action_at TIMESTAMPTZ,
  author_user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT client_interactions_type_chk CHECK (
    interaction_type IN ('call', 'meeting', 'email', 'message', 'task', 'note')
  )
);

CREATE INDEX IF NOT EXISTS client_interactions_client_id_idx
  ON client_interactions (client_id, happened_at DESC);

-- Catalog and warehouses
CREATE TABLE IF NOT EXISTS product_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  parent_id UUID REFERENCES product_categories(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  code TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  archived_at TIMESTAMPTZ,
  CONSTRAINT product_categories_name_length_chk CHECK (char_length(name) BETWEEN 2 AND 120)
);

CREATE INDEX IF NOT EXISTS product_categories_company_id_idx
  ON product_categories (company_id);

CREATE UNIQUE INDEX IF NOT EXISTS product_categories_company_name_uq
  ON product_categories (company_id, lower(name))
  WHERE archived_at IS NULL;

CREATE TABLE IF NOT EXISTS warehouses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  code TEXT,
  name TEXT NOT NULL,
  warehouse_type TEXT NOT NULL DEFAULT 'storage',
  address_line TEXT,
  manager_user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  archived_at TIMESTAMPTZ,
  CONSTRAINT warehouses_type_chk CHECK (warehouse_type IN ('storage', 'shop', 'transit', 'returns')),
  CONSTRAINT warehouses_name_length_chk CHECK (char_length(name) BETWEEN 2 AND 120)
);

CREATE INDEX IF NOT EXISTS warehouses_company_id_idx
  ON warehouses (company_id);

CREATE UNIQUE INDEX IF NOT EXISTS warehouses_company_code_uq
  ON warehouses (company_id, lower(code))
  WHERE code IS NOT NULL AND archived_at IS NULL;

CREATE TABLE IF NOT EXISTS products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  category_id UUID REFERENCES product_categories(id) ON DELETE SET NULL,
  sku TEXT NOT NULL,
  barcode TEXT,
  name TEXT NOT NULL,
  description TEXT,
  unit_name TEXT NOT NULL DEFAULT 'pcs',
  tracking_type TEXT NOT NULL DEFAULT 'none',
  min_quantity NUMERIC(18, 3) NOT NULL DEFAULT 0,
  sale_price NUMERIC(18, 2) NOT NULL DEFAULT 0,
  cost_price NUMERIC(18, 2) NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_by_user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
  updated_by_user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  archived_at TIMESTAMPTZ,
  CONSTRAINT products_tracking_type_chk CHECK (tracking_type IN ('none', 'batch', 'serial')),
  CONSTRAINT products_sku_length_chk CHECK (char_length(sku) BETWEEN 1 AND 64),
  CONSTRAINT products_name_length_chk CHECK (char_length(name) BETWEEN 2 AND 200),
  CONSTRAINT products_min_quantity_chk CHECK (min_quantity >= 0),
  CONSTRAINT products_sale_price_chk CHECK (sale_price >= 0),
  CONSTRAINT products_cost_price_chk CHECK (cost_price >= 0)
);

CREATE INDEX IF NOT EXISTS products_company_id_idx
  ON products (company_id);

CREATE INDEX IF NOT EXISTS products_company_category_id_idx
  ON products (company_id, category_id);

CREATE UNIQUE INDEX IF NOT EXISTS products_company_sku_uq
  ON products (company_id, lower(sku))
  WHERE archived_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS products_company_barcode_uq
  ON products (company_id, barcode)
  WHERE barcode IS NOT NULL AND archived_at IS NULL;

CREATE TABLE IF NOT EXISTS inventory_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  document_no TEXT NOT NULL,
  document_type TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'draft',
  document_date DATE NOT NULL,
  warehouse_id UUID REFERENCES warehouses(id) ON DELETE SET NULL,
  related_warehouse_id UUID REFERENCES warehouses(id) ON DELETE SET NULL,
  client_id UUID REFERENCES clients(id) ON DELETE SET NULL,
  source_module TEXT,
  source_reference TEXT,
  note TEXT,
  created_by_user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
  posted_by_user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
  posted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  cancelled_at TIMESTAMPTZ,
  CONSTRAINT inventory_documents_type_chk CHECK (
    document_type IN (
      'opening',
      'purchase_receipt',
      'sale_issue',
      'transfer',
      'adjustment',
      'return_in',
      'return_out',
      'write_off',
      'production_in',
      'production_out'
    )
  ),
  CONSTRAINT inventory_documents_status_chk CHECK (status IN ('draft', 'posted', 'cancelled'))
);

CREATE INDEX IF NOT EXISTS inventory_documents_company_id_idx
  ON inventory_documents (company_id, document_date DESC);

CREATE UNIQUE INDEX IF NOT EXISTS inventory_documents_company_document_no_uq
  ON inventory_documents (company_id, lower(document_no));

CREATE TABLE IF NOT EXISTS inventory_document_lines (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id UUID NOT NULL REFERENCES inventory_documents(id) ON DELETE CASCADE,
  line_no INTEGER NOT NULL,
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
  quantity NUMERIC(18, 3) NOT NULL,
  unit_price NUMERIC(18, 2) NOT NULL DEFAULT 0,
  unit_cost NUMERIC(18, 2) NOT NULL DEFAULT 0,
  line_total NUMERIC(18, 2) GENERATED ALWAYS AS (quantity * unit_price) STORED,
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT inventory_document_lines_qty_chk CHECK (quantity > 0),
  CONSTRAINT inventory_document_lines_unit_price_chk CHECK (unit_price >= 0),
  CONSTRAINT inventory_document_lines_unit_cost_chk CHECK (unit_cost >= 0),
  CONSTRAINT inventory_document_lines_line_no_chk CHECK (line_no > 0),
  UNIQUE (document_id, line_no)
);

CREATE INDEX IF NOT EXISTS inventory_document_lines_document_id_idx
  ON inventory_document_lines (document_id);

CREATE INDEX IF NOT EXISTS inventory_document_lines_product_id_idx
  ON inventory_document_lines (product_id);

CREATE TABLE IF NOT EXISTS inventory_movements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  warehouse_id UUID NOT NULL REFERENCES warehouses(id) ON DELETE RESTRICT,
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
  document_id UUID NOT NULL REFERENCES inventory_documents(id) ON DELETE CASCADE,
  document_line_id UUID REFERENCES inventory_document_lines(id) ON DELETE CASCADE,
  movement_type TEXT NOT NULL,
  quantity_delta NUMERIC(18, 3) NOT NULL,
  unit_cost NUMERIC(18, 2) NOT NULL DEFAULT 0,
  total_cost NUMERIC(18, 2) NOT NULL DEFAULT 0,
  balance_after NUMERIC(18, 3),
  happened_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT inventory_movements_type_chk CHECK (
    movement_type IN ('in', 'out', 'transfer_in', 'transfer_out', 'adjustment', 'reserve', 'release')
  ),
  CONSTRAINT inventory_movements_qty_nonzero_chk CHECK (quantity_delta <> 0)
);

CREATE INDEX IF NOT EXISTS inventory_movements_company_product_idx
  ON inventory_movements (company_id, product_id, happened_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS inventory_movements_company_warehouse_idx
  ON inventory_movements (company_id, warehouse_id, happened_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS inventory_movements_document_id_idx
  ON inventory_movements (document_id);

CREATE TABLE IF NOT EXISTS inventory_balances (
  company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  warehouse_id UUID NOT NULL REFERENCES warehouses(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  quantity_on_hand NUMERIC(18, 3) NOT NULL DEFAULT 0,
  quantity_reserved NUMERIC(18, 3) NOT NULL DEFAULT 0,
  average_cost NUMERIC(18, 2) NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (company_id, warehouse_id, product_id),
  CONSTRAINT inventory_balances_on_hand_chk CHECK (quantity_on_hand >= 0),
  CONSTRAINT inventory_balances_reserved_chk CHECK (quantity_reserved >= 0),
  CONSTRAINT inventory_balances_average_cost_chk CHECK (average_cost >= 0)
);

CREATE INDEX IF NOT EXISTS inventory_balances_company_product_idx
  ON inventory_balances (company_id, product_id);

-- Finance
CREATE TABLE IF NOT EXISTS cash_accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  account_type TEXT NOT NULL,
  currency_code CHAR(3) NOT NULL DEFAULT 'KZT',
  bank_name TEXT,
  iban TEXT,
  bik TEXT,
  opening_balance NUMERIC(18, 2) NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  archived_at TIMESTAMPTZ,
  CONSTRAINT cash_accounts_type_chk CHECK (account_type IN ('bank', 'cash', 'e_wallet', 'card', 'other')),
  CONSTRAINT cash_accounts_currency_code_chk CHECK (currency_code ~ '^[A-Z]{3}$'),
  CONSTRAINT cash_accounts_opening_balance_chk CHECK (opening_balance >= 0),
  CONSTRAINT cash_accounts_name_length_chk CHECK (char_length(name) BETWEEN 2 AND 120)
);

CREATE INDEX IF NOT EXISTS cash_accounts_company_id_idx
  ON cash_accounts (company_id);

CREATE UNIQUE INDEX IF NOT EXISTS cash_accounts_company_name_uq
  ON cash_accounts (company_id, lower(name))
  WHERE archived_at IS NULL;

CREATE TABLE IF NOT EXISTS money_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  parent_id UUID REFERENCES money_categories(id) ON DELETE SET NULL,
  direction TEXT NOT NULL,
  name TEXT NOT NULL,
  color_hex TEXT,
  is_system BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  archived_at TIMESTAMPTZ,
  CONSTRAINT money_categories_direction_chk CHECK (direction IN ('income', 'expense', 'transfer')),
  CONSTRAINT money_categories_color_chk CHECK (color_hex IS NULL OR color_hex ~ '^#[0-9A-Fa-f]{6}$')
);

CREATE INDEX IF NOT EXISTS money_categories_company_id_idx
  ON money_categories (company_id);

CREATE UNIQUE INDEX IF NOT EXISTS money_categories_company_name_direction_uq
  ON money_categories (company_id, direction, lower(name))
  WHERE archived_at IS NULL;

CREATE TABLE IF NOT EXISTS money_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  document_no TEXT NOT NULL,
  document_type TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'draft',
  operation_date DATE NOT NULL,
  primary_account_id UUID REFERENCES cash_accounts(id) ON DELETE SET NULL,
  secondary_account_id UUID REFERENCES cash_accounts(id) ON DELETE SET NULL,
  client_id UUID REFERENCES clients(id) ON DELETE SET NULL,
  source_module TEXT,
  source_reference TEXT,
  description TEXT,
  created_by_user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
  posted_by_user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
  posted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  cancelled_at TIMESTAMPTZ,
  CONSTRAINT money_documents_type_chk CHECK (
    document_type IN (
      'opening',
      'receipt',
      'payment',
      'transfer',
      'adjustment',
      'sale_payment',
      'purchase_payment',
      'salary',
      'tax'
    )
  ),
  CONSTRAINT money_documents_status_chk CHECK (status IN ('draft', 'posted', 'cancelled'))
);

CREATE INDEX IF NOT EXISTS money_documents_company_id_idx
  ON money_documents (company_id, operation_date DESC);

CREATE UNIQUE INDEX IF NOT EXISTS money_documents_company_document_no_uq
  ON money_documents (company_id, lower(document_no));

CREATE TABLE IF NOT EXISTS money_document_lines (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id UUID NOT NULL REFERENCES money_documents(id) ON DELETE CASCADE,
  line_no INTEGER NOT NULL,
  category_id UUID REFERENCES money_categories(id) ON DELETE SET NULL,
  amount NUMERIC(18, 2) NOT NULL,
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT money_document_lines_amount_chk CHECK (amount > 0),
  CONSTRAINT money_document_lines_line_no_chk CHECK (line_no > 0),
  UNIQUE (document_id, line_no)
);

CREATE INDEX IF NOT EXISTS money_document_lines_document_id_idx
  ON money_document_lines (document_id);

CREATE TABLE IF NOT EXISTS money_movements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  account_id UUID NOT NULL REFERENCES cash_accounts(id) ON DELETE RESTRICT,
  document_id UUID NOT NULL REFERENCES money_documents(id) ON DELETE CASCADE,
  document_line_id UUID REFERENCES money_document_lines(id) ON DELETE CASCADE,
  client_id UUID REFERENCES clients(id) ON DELETE SET NULL,
  category_id UUID REFERENCES money_categories(id) ON DELETE SET NULL,
  transfer_group_id UUID,
  movement_direction TEXT NOT NULL,
  amount NUMERIC(18, 2) NOT NULL,
  signed_amount NUMERIC(18, 2) NOT NULL,
  balance_after NUMERIC(18, 2),
  happened_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT money_movements_direction_chk CHECK (movement_direction IN ('income', 'expense', 'transfer_in', 'transfer_out')),
  CONSTRAINT money_movements_amount_chk CHECK (amount > 0),
  CONSTRAINT money_movements_signed_amount_chk CHECK (signed_amount <> 0)
);

CREATE INDEX IF NOT EXISTS money_movements_company_account_idx
  ON money_movements (company_id, account_id, happened_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS money_movements_company_category_idx
  ON money_movements (company_id, category_id, happened_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS money_movements_document_id_idx
  ON money_movements (document_id);

CREATE TABLE IF NOT EXISTS cash_account_balances (
  account_id UUID PRIMARY KEY REFERENCES cash_accounts(id) ON DELETE CASCADE,
  balance_amount NUMERIC(18, 2) NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Updated-at triggers
DROP TRIGGER IF EXISTS trg_companies_set_updated_at ON companies;
CREATE TRIGGER trg_companies_set_updated_at
BEFORE UPDATE ON companies
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_company_memberships_set_updated_at ON company_memberships;
CREATE TRIGGER trg_company_memberships_set_updated_at
BEFORE UPDATE ON company_memberships
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_clients_set_updated_at ON clients;
CREATE TRIGGER trg_clients_set_updated_at
BEFORE UPDATE ON clients
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_client_interactions_set_updated_at ON client_interactions;
CREATE TRIGGER trg_client_interactions_set_updated_at
BEFORE UPDATE ON client_interactions
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_product_categories_set_updated_at ON product_categories;
CREATE TRIGGER trg_product_categories_set_updated_at
BEFORE UPDATE ON product_categories
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_warehouses_set_updated_at ON warehouses;
CREATE TRIGGER trg_warehouses_set_updated_at
BEFORE UPDATE ON warehouses
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_products_set_updated_at ON products;
CREATE TRIGGER trg_products_set_updated_at
BEFORE UPDATE ON products
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_inventory_documents_set_updated_at ON inventory_documents;
CREATE TRIGGER trg_inventory_documents_set_updated_at
BEFORE UPDATE ON inventory_documents
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_inventory_balances_set_updated_at ON inventory_balances;
CREATE TRIGGER trg_inventory_balances_set_updated_at
BEFORE UPDATE ON inventory_balances
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_cash_accounts_set_updated_at ON cash_accounts;
CREATE TRIGGER trg_cash_accounts_set_updated_at
BEFORE UPDATE ON cash_accounts
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_money_categories_set_updated_at ON money_categories;
CREATE TRIGGER trg_money_categories_set_updated_at
BEFORE UPDATE ON money_categories
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_money_documents_set_updated_at ON money_documents;
CREATE TRIGGER trg_money_documents_set_updated_at
BEFORE UPDATE ON money_documents
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_cash_account_balances_set_updated_at ON cash_account_balances;
CREATE TRIGGER trg_cash_account_balances_set_updated_at
BEFORE UPDATE ON cash_account_balances
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();
