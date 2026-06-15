-- Payroll rules / Правила начисления сдельной
-- Комиссия с продаж (per-employee), сумма за рецепт и участники производства.

-- Комиссия с продаж у сотрудника: процент и база (выручка / прибыль)
ALTER TABLE employees
  ADD COLUMN IF NOT EXISTS sales_percent NUMERIC(6,2) NOT NULL DEFAULT 0;

ALTER TABLE employees
  ADD COLUMN IF NOT EXISTS sales_basis TEXT NOT NULL DEFAULT 'revenue';

ALTER TABLE employees
  DROP CONSTRAINT IF EXISTS employees_sales_percent_chk;
ALTER TABLE employees
  ADD CONSTRAINT employees_sales_percent_chk
    CHECK (sales_percent >= 0 AND sales_percent <= 100);

ALTER TABLE employees
  DROP CONSTRAINT IF EXISTS employees_sales_basis_chk;
ALTER TABLE employees
  ADD CONSTRAINT employees_sales_basis_chk
    CHECK (sales_basis IN ('revenue', 'profit'));

-- Сумма к распределению за партию по рецепту
ALTER TABLE recipes
  ADD COLUMN IF NOT EXISTS payroll_amount NUMERIC(18,2) NOT NULL DEFAULT 0;

ALTER TABLE recipes
  DROP CONSTRAINT IF EXISTS recipes_payroll_amount_chk;
ALTER TABLE recipes
  ADD CONSTRAINT recipes_payroll_amount_chk CHECK (payroll_amount >= 0);

-- Участники производственного заказа с долями (в сумме 100%)
CREATE TABLE IF NOT EXISTS production_order_participants (
  id            UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id      UUID          NOT NULL REFERENCES production_orders(id) ON DELETE CASCADE,
  employee_id   UUID          NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  share_percent NUMERIC(6,2)  NOT NULL DEFAULT 0,
  created_at    TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  UNIQUE (order_id, employee_id),
  CONSTRAINT production_order_participants_share_chk
    CHECK (share_percent > 0 AND share_percent <= 100)
);

CREATE INDEX IF NOT EXISTS production_order_participants_order_id_idx
  ON production_order_participants (order_id);

CREATE INDEX IF NOT EXISTS production_order_participants_employee_id_idx
  ON production_order_participants (employee_id);
