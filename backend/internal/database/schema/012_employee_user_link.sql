-- Employee ↔ user link for personal payroll views.

ALTER TABLE employees
  ADD COLUMN IF NOT EXISTS user_id TEXT REFERENCES users(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS employees_company_user_id_idx
  ON employees (company_id, user_id)
  WHERE user_id IS NOT NULL AND archived_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS employees_company_active_user_uq
  ON employees (company_id, user_id)
  WHERE user_id IS NOT NULL AND status = 'active' AND archived_at IS NULL;
