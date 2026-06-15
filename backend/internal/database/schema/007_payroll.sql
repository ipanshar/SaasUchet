-- Payroll / Зарплата
-- Справочник сотрудников, расчётные ведомости и строки начислений.

-- Сотрудники (отдельный справочник, опционально связан с учётной записью)
CREATE TABLE IF NOT EXISTS employees (
  id                UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id        UUID         NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  user_id           TEXT         REFERENCES users(id) ON DELETE SET NULL,
  full_name         TEXT         NOT NULL,
  position          TEXT         NOT NULL DEFAULT '',
  iin               TEXT,
  phone             TEXT,
  salary_type       TEXT         NOT NULL DEFAULT 'monthly',
  monthly_salary    NUMERIC(18,2) NOT NULL DEFAULT 0,
  hourly_rate       NUMERIC(18,2) NOT NULL DEFAULT 0,
  piece_rate        NUMERIC(18,2) NOT NULL DEFAULT 0,
  piece_rate_source TEXT         NOT NULL DEFAULT 'none',
  standard_days     INTEGER      NOT NULL DEFAULT 22,
  hire_date         DATE,
  status            TEXT         NOT NULL DEFAULT 'active',
  notes             TEXT         NOT NULL DEFAULT '',
  created_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  archived_at       TIMESTAMPTZ,
  CONSTRAINT employees_full_name_length_chk CHECK (char_length(full_name) BETWEEN 2 AND 160),
  CONSTRAINT employees_salary_type_chk CHECK (
    salary_type IN ('monthly', 'hourly', 'piece_rate', 'bonus', 'combined')
  ),
  CONSTRAINT employees_piece_source_chk CHECK (
    piece_rate_source IN ('none', 'production', 'sales', 'purchases')
  ),
  CONSTRAINT employees_status_chk CHECK (status IN ('active', 'inactive')),
  CONSTRAINT employees_iin_chk CHECK (iin IS NULL OR iin ~ '^[0-9]{12}$'),
  CONSTRAINT employees_monthly_salary_chk CHECK (monthly_salary >= 0),
  CONSTRAINT employees_hourly_rate_chk CHECK (hourly_rate >= 0),
  CONSTRAINT employees_piece_rate_chk CHECK (piece_rate >= 0),
  CONSTRAINT employees_standard_days_chk CHECK (standard_days BETWEEN 1 AND 31)
);

CREATE INDEX IF NOT EXISTS employees_company_id_idx
  ON employees (company_id)
  WHERE archived_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS employees_company_full_name_uq
  ON employees (company_id, lower(full_name))
  WHERE archived_at IS NULL;

-- Расчётные ведомости (период)
CREATE TABLE IF NOT EXISTS payroll_periods (
  id                 UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id         UUID         NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  period_year        INTEGER      NOT NULL,
  period_month       INTEGER      NOT NULL,
  title              TEXT         NOT NULL DEFAULT '',
  status             TEXT         NOT NULL DEFAULT 'draft',
  created_by_user_id TEXT         REFERENCES users(id) ON DELETE SET NULL,
  created_at         TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  CONSTRAINT payroll_periods_month_chk CHECK (period_month BETWEEN 1 AND 12),
  CONSTRAINT payroll_periods_year_chk CHECK (period_year BETWEEN 2000 AND 2200),
  CONSTRAINT payroll_periods_status_chk CHECK (
    status IN ('draft', 'calculated', 'paid', 'cancelled')
  )
);

CREATE INDEX IF NOT EXISTS payroll_periods_company_id_idx
  ON payroll_periods (company_id, period_year DESC, period_month DESC);

CREATE UNIQUE INDEX IF NOT EXISTS payroll_periods_company_period_uq
  ON payroll_periods (company_id, period_year, period_month);

-- Строки ведомости: одна на сотрудника
CREATE TABLE IF NOT EXISTS payroll_entries (
  id                UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  period_id         UUID          NOT NULL REFERENCES payroll_periods(id) ON DELETE CASCADE,
  employee_id       UUID          NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  -- табель (сводка за период)
  days_worked       NUMERIC(8,2)  NOT NULL DEFAULT 0,
  hours_worked      NUMERIC(8,2)  NOT NULL DEFAULT 0,
  overtime_hours    NUMERIC(8,2)  NOT NULL DEFAULT 0,
  vacation_days     NUMERIC(8,2)  NOT NULL DEFAULT 0,
  sick_days         NUMERIC(8,2)  NOT NULL DEFAULT 0,
  absent_days       NUMERIC(8,2)  NOT NULL DEFAULT 0,
  -- начисления
  base_amount       NUMERIC(18,2) NOT NULL DEFAULT 0,
  piece_amount      NUMERIC(18,2) NOT NULL DEFAULT 0,
  bonus_amount      NUMERIC(18,2) NOT NULL DEFAULT 0,
  overtime_amount   NUMERIC(18,2) NOT NULL DEFAULT 0,
  vacation_amount   NUMERIC(18,2) NOT NULL DEFAULT 0,
  deductions        NUMERIC(18,2) NOT NULL DEFAULT 0,
  gross_amount      NUMERIC(18,2) NOT NULL DEFAULT 0,
  net_amount        NUMERIC(18,2) NOT NULL DEFAULT 0,
  -- выплата
  money_document_id UUID          REFERENCES money_documents(id) ON DELETE SET NULL,
  paid_at           TIMESTAMPTZ,
  notes             TEXT          NOT NULL DEFAULT '',
  created_at        TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  UNIQUE (period_id, employee_id)
);

CREATE INDEX IF NOT EXISTS payroll_entries_period_id_idx
  ON payroll_entries (period_id);

CREATE INDEX IF NOT EXISTS payroll_entries_employee_id_idx
  ON payroll_entries (employee_id);

-- Задел под автоматическую сдельную оплату: связь документов с сотрудником
ALTER TABLE production_orders
  ADD COLUMN IF NOT EXISTS employee_id UUID REFERENCES employees(id) ON DELETE SET NULL;

ALTER TABLE inventory_documents
  ADD COLUMN IF NOT EXISTS employee_id UUID REFERENCES employees(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS production_orders_employee_id_idx
  ON production_orders (employee_id)
  WHERE employee_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS inventory_documents_employee_id_idx
  ON inventory_documents (employee_id)
  WHERE employee_id IS NOT NULL;

-- Updated-at триггеры
DROP TRIGGER IF EXISTS trg_employees_set_updated_at ON employees;
CREATE TRIGGER trg_employees_set_updated_at
BEFORE UPDATE ON employees
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_payroll_periods_set_updated_at ON payroll_periods;
CREATE TRIGGER trg_payroll_periods_set_updated_at
BEFORE UPDATE ON payroll_periods
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_payroll_entries_set_updated_at ON payroll_entries;
CREATE TRIGGER trg_payroll_entries_set_updated_at
BEFORE UPDATE ON payroll_entries
FOR EACH ROW EXECUTE FUNCTION set_updated_at();
