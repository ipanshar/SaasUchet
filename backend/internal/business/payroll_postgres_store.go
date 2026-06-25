package business

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"math"
	"strings"
	"time"

	"github.com/altyncloud/saas-uchet/backend/internal/auth"
)

// ── Employees ─────────────────────────────────────────────────────────────────

func (s *PostgresStore) ListEmployees(user auth.User) ([]Employee, error) {
	ctx, cancel := s.withTimeout()
	defer cancel()

	companyID, err := s.ensurePrimaryCompany(ctx, user)
	if err != nil {
		return nil, err
	}

	rows, err := s.db.QueryContext(ctx,
		`SELECT id::text, full_name, position, COALESCE(iin,''), COALESCE(phone,''),
		        salary_type, monthly_salary, hourly_rate, piece_rate, piece_rate_source,
		        sales_percent, sales_basis,
		        standard_days, COALESCE(hire_date::text,''), status, notes
		 FROM employees
		 WHERE company_id = $1::uuid AND archived_at IS NULL
		 ORDER BY lower(full_name) ASC`,
		companyID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	employees := make([]Employee, 0)
	for rows.Next() {
		emp, scanErr := scanEmployee(rows)
		if scanErr != nil {
			return nil, scanErr
		}
		employees = append(employees, emp)
	}
	return employees, rows.Err()
}

func (s *PostgresStore) EmployeeStatement(user auth.User, employeeID string, from string, to string) (EmployeeStatement, error) {
	from = strings.TrimSpace(from)
	to = strings.TrimSpace(to)
	employeeID = strings.TrimSpace(employeeID)
	if _, err := time.Parse("2006-01-02", from); err != nil {
		return EmployeeStatement{}, fmt.Errorf("%w: invalid from date", ErrValidation)
	}
	if _, err := time.Parse("2006-01-02", to); err != nil {
		return EmployeeStatement{}, fmt.Errorf("%w: invalid to date", ErrValidation)
	}

	ctx, cancel := s.withTimeout()
	defer cancel()

	companyID, err := s.ensurePrimaryCompany(ctx, user)
	if err != nil {
		return EmployeeStatement{}, err
	}

	statement := EmployeeStatement{EmployeeID: employeeID, From: from, To: to}

	if err := s.db.QueryRowContext(
		ctx,
		`SELECT full_name, COALESCE(position, '')
		 FROM employees WHERE id = $1::uuid AND company_id = $2::uuid`,
		employeeID,
		companyID,
	).Scan(&statement.EmployeeName, &statement.Position); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return EmployeeStatement{}, fmt.Errorf("%w: employee not found", ErrValidation)
		}
		return EmployeeStatement{}, err
	}

	rows, err := s.db.QueryContext(
		ctx,
		`SELECT p.period_year, p.period_month, p.title, p.status,
		        e.days_worked, e.hours_worked,
		        e.base_amount, e.piece_amount, e.bonus_amount, e.overtime_amount, e.vacation_amount,
		        e.deductions, e.gross_amount, e.net_amount,
		        (e.money_document_id IS NOT NULL), COALESCE(e.paid_at::text, '')
		 FROM payroll_entries e
		 JOIN payroll_periods p ON p.id = e.period_id
		 WHERE p.company_id = $1::uuid AND e.employee_id = $2::uuid
		   AND make_date(p.period_year, p.period_month, 1) >= date_trunc('month', $3::date)::date
		   AND make_date(p.period_year, p.period_month, 1) <= $4::date
		 ORDER BY p.period_year ASC, p.period_month ASC`,
		companyID,
		employeeID,
		from,
		to,
	)
	if err != nil {
		return EmployeeStatement{}, err
	}
	defer rows.Close()

	entries := make([]EmployeeStatementEntry, 0)
	for rows.Next() {
		var e EmployeeStatementEntry
		if err := rows.Scan(
			&e.PeriodYear,
			&e.PeriodMonth,
			&e.Title,
			&e.Status,
			&e.DaysWorked,
			&e.HoursWorked,
			&e.BaseAmount,
			&e.PieceAmount,
			&e.BonusAmount,
			&e.OvertimeAmount,
			&e.VacationAmount,
			&e.Deductions,
			&e.GrossAmount,
			&e.NetAmount,
			&e.IsPaid,
			&e.PaidAt,
		); err != nil {
			return EmployeeStatement{}, err
		}
		statement.TotalBase += e.BaseAmount
		statement.TotalPiece += e.PieceAmount
		statement.TotalBonus += e.BonusAmount
		statement.TotalOvertime += e.OvertimeAmount
		statement.TotalVacation += e.VacationAmount
		statement.TotalDeductions += e.Deductions
		statement.TotalGross += e.GrossAmount
		statement.TotalNet += e.NetAmount
		if e.IsPaid {
			statement.TotalPaid += e.NetAmount
		}
		entries = append(entries, e)
	}
	if err := rows.Err(); err != nil {
		return EmployeeStatement{}, err
	}

	statement.Entries = entries
	return statement, nil
}

func (s *PostgresStore) CreateEmployee(user auth.User, input CreateEmployeeInput) (Employee, error) {
	ctx, cancel := s.withTimeout()
	defer cancel()

	companyID, err := s.ensurePrimaryCompany(ctx, user)
	if err != nil {
		return Employee{}, err
	}

	normalized := NormalizeEmployeeInput(input)
	if err := ValidateEmployeeInput(normalized); err != nil {
		return Employee{}, err
	}

	id := mustGenerateProductID()
	_, err = s.db.ExecContext(ctx,
		`INSERT INTO employees
		   (id, company_id, full_name, position, iin, phone, salary_type,
		    monthly_salary, hourly_rate, piece_rate, piece_rate_source,
		    sales_percent, sales_basis,
		    standard_days, hire_date, status, notes, created_at, updated_at)
		 VALUES
		   ($1::uuid, $2::uuid, $3, $4, NULLIF($5,''), NULLIF($6,''), $7,
		    $8, $9, $10, $11,
		    $12, $13,
		    $14, NULLIF($15,'')::date, $16, $17, NOW(), NOW())`,
		id, companyID, normalized.FullName, normalized.Position, normalized.IIN, normalized.Phone,
		normalized.SalaryType, normalized.MonthlySalary, normalized.HourlyRate, normalized.PieceRate,
		normalized.PieceRateSource, normalized.SalesPercent, normalized.SalesBasis,
		normalized.StandardDays, normalized.HireDate, normalized.Status, normalized.Notes,
	)
	if err != nil {
		return Employee{}, err
	}

	return s.getEmployee(ctx, companyID, id)
}

func (s *PostgresStore) UpdateEmployee(user auth.User, employeeID string, input CreateEmployeeInput) (Employee, error) {
	ctx, cancel := s.withTimeout()
	defer cancel()

	companyID, err := s.ensurePrimaryCompany(ctx, user)
	if err != nil {
		return Employee{}, err
	}

	normalized := NormalizeEmployeeInput(input)
	if err := ValidateEmployeeInput(normalized); err != nil {
		return Employee{}, err
	}

	result, err := s.db.ExecContext(ctx,
		`UPDATE employees SET
		   full_name=$3, position=$4, iin=NULLIF($5,''), phone=NULLIF($6,''), salary_type=$7,
		   monthly_salary=$8, hourly_rate=$9, piece_rate=$10, piece_rate_source=$11,
		   sales_percent=$12, sales_basis=$13,
		   standard_days=$14, hire_date=NULLIF($15,'')::date, status=$16, notes=$17, updated_at=NOW()
		 WHERE id=$1::uuid AND company_id=$2::uuid AND archived_at IS NULL`,
		employeeID, companyID, normalized.FullName, normalized.Position, normalized.IIN, normalized.Phone,
		normalized.SalaryType, normalized.MonthlySalary, normalized.HourlyRate, normalized.PieceRate,
		normalized.PieceRateSource, normalized.SalesPercent, normalized.SalesBasis,
		normalized.StandardDays, normalized.HireDate, normalized.Status, normalized.Notes,
	)
	if err != nil {
		return Employee{}, err
	}
	if affected, _ := result.RowsAffected(); affected == 0 {
		return Employee{}, fmt.Errorf("%w: employee not found", ErrValidation)
	}

	return s.getEmployee(ctx, companyID, employeeID)
}

func (s *PostgresStore) DeleteEmployee(user auth.User, employeeID string) error {
	ctx, cancel := s.withTimeout()
	defer cancel()

	companyID, err := s.ensurePrimaryCompany(ctx, user)
	if err != nil {
		return err
	}

	result, err := s.db.ExecContext(ctx,
		`UPDATE employees SET archived_at=NOW(), updated_at=NOW()
		 WHERE id=$1::uuid AND company_id=$2::uuid AND archived_at IS NULL`,
		employeeID, companyID,
	)
	if err != nil {
		return err
	}
	if affected, _ := result.RowsAffected(); affected == 0 {
		return fmt.Errorf("%w: employee not found", ErrValidation)
	}
	return nil
}

func (s *PostgresStore) getEmployee(ctx context.Context, companyID string, employeeID string) (Employee, error) {
	row := s.db.QueryRowContext(ctx,
		`SELECT id::text, full_name, position, COALESCE(iin,''), COALESCE(phone,''),
		        salary_type, monthly_salary, hourly_rate, piece_rate, piece_rate_source,
		        sales_percent, sales_basis,
		        standard_days, COALESCE(hire_date::text,''), status, notes
		 FROM employees
		 WHERE id=$1::uuid AND company_id=$2::uuid`,
		employeeID, companyID,
	)
	return scanEmployee(row)
}

type rowScanner interface {
	Scan(dest ...any) error
}

func scanEmployee(row rowScanner) (Employee, error) {
	var emp Employee
	var monthly, hourly, piece float64
	if err := row.Scan(
		&emp.ID, &emp.FullName, &emp.Position, &emp.IIN, &emp.Phone,
		&emp.SalaryType, &monthly, &hourly, &piece, &emp.PieceRateSource,
		&emp.SalesPercent, &emp.SalesBasis,
		&emp.StandardDays, &emp.HireDate, &emp.Status, &emp.Notes,
	); err != nil {
		return Employee{}, err
	}
	emp.MonthlySalary = int(monthly)
	emp.HourlyRate = int(hourly)
	emp.PieceRate = int(piece)
	return emp, nil
}

// ── Payroll periods ───────────────────────────────────────────────────────────

func (s *PostgresStore) ListPayrollPeriods(user auth.User) ([]PayrollPeriod, error) {
	ctx, cancel := s.withTimeout()
	defer cancel()

	companyID, err := s.ensurePrimaryCompany(ctx, user)
	if err != nil {
		return nil, err
	}

	rows, err := s.db.QueryContext(ctx,
		`SELECT p.id::text, p.period_year, p.period_month, p.title, p.status,
		        COALESCE(p.created_at::text,''),
		        COUNT(e.id),
		        COALESCE(SUM(e.net_amount), 0),
		        COUNT(e.id) FILTER (WHERE e.money_document_id IS NOT NULL)
		 FROM payroll_periods p
		 LEFT JOIN payroll_entries e ON e.period_id = p.id
		 WHERE p.company_id = $1::uuid
		 GROUP BY p.id
		 ORDER BY p.period_year DESC, p.period_month DESC`,
		companyID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	periods := make([]PayrollPeriod, 0)
	for rows.Next() {
		var p PayrollPeriod
		var totalNet float64
		if err := rows.Scan(&p.ID, &p.PeriodYear, &p.PeriodMonth, &p.Title, &p.Status,
			&p.CreatedAt, &p.EmployeeCount, &totalNet, &p.PaidCount); err != nil {
			return nil, err
		}
		p.TotalNet = int(totalNet)
		periods = append(periods, p)
	}
	return periods, rows.Err()
}

func (s *PostgresStore) CreatePayrollPeriod(user auth.User, input CreatePayrollPeriodInput) (PayrollPeriod, error) {
	ctx, cancel := s.withTimeout()
	defer cancel()

	companyID, err := s.ensurePrimaryCompany(ctx, user)
	if err != nil {
		return PayrollPeriod{}, err
	}

	normalized := NormalizePayrollPeriodInput(input)
	if err := ValidatePayrollPeriodInput(normalized); err != nil {
		return PayrollPeriod{}, err
	}

	var exists bool
	if err := s.db.QueryRowContext(ctx,
		`SELECT EXISTS(SELECT 1 FROM payroll_periods
		   WHERE company_id=$1::uuid AND period_year=$2 AND period_month=$3)`,
		companyID, normalized.PeriodYear, normalized.PeriodMonth,
	).Scan(&exists); err != nil {
		return PayrollPeriod{}, err
	}
	if exists {
		return PayrollPeriod{}, fmt.Errorf("%w: payroll period already exists", ErrValidation)
	}

	id := mustGenerateProductID()
	_, err = s.db.ExecContext(ctx,
		`INSERT INTO payroll_periods
		   (id, company_id, period_year, period_month, title, status, created_by_user_id, created_at, updated_at)
		 VALUES ($1::uuid, $2::uuid, $3, $4, $5, 'draft', $6, NOW(), NOW())`,
		id, companyID, normalized.PeriodYear, normalized.PeriodMonth, normalized.Title, user.ID,
	)
	if err != nil {
		return PayrollPeriod{}, err
	}

	detail, err := s.GetPayrollPeriod(user, id)
	if err != nil {
		return PayrollPeriod{}, err
	}
	return detail.Period, nil
}

func (s *PostgresStore) GetPayrollPeriod(user auth.User, periodID string) (PayrollPeriodDetail, error) {
	ctx, cancel := s.withTimeout()
	defer cancel()

	companyID, err := s.ensurePrimaryCompany(ctx, user)
	if err != nil {
		return PayrollPeriodDetail{}, err
	}
	return s.loadPayrollPeriod(ctx, companyID, periodID)
}

func (s *PostgresStore) loadPayrollPeriod(ctx context.Context, companyID string, periodID string) (PayrollPeriodDetail, error) {
	var detail PayrollPeriodDetail
	var totalNet float64
	err := s.db.QueryRowContext(ctx,
		`SELECT p.id::text, p.period_year, p.period_month, p.title, p.status,
		        COALESCE(p.created_at::text,''),
		        COUNT(e.id),
		        COALESCE(SUM(e.net_amount), 0),
		        COUNT(e.id) FILTER (WHERE e.money_document_id IS NOT NULL)
		 FROM payroll_periods p
		 LEFT JOIN payroll_entries e ON e.period_id = p.id
		 WHERE p.id = $1::uuid AND p.company_id = $2::uuid
		 GROUP BY p.id`,
		periodID, companyID,
	).Scan(&detail.Period.ID, &detail.Period.PeriodYear, &detail.Period.PeriodMonth,
		&detail.Period.Title, &detail.Period.Status, &detail.Period.CreatedAt,
		&detail.Period.EmployeeCount, &totalNet, &detail.Period.PaidCount)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return PayrollPeriodDetail{}, fmt.Errorf("%w: payroll period not found", ErrValidation)
		}
		return PayrollPeriodDetail{}, err
	}
	detail.Period.TotalNet = int(totalNet)

	rows, err := s.db.QueryContext(ctx,
		`SELECT e.id::text, e.employee_id::text, emp.full_name, emp.position, emp.salary_type,
		        e.days_worked, e.hours_worked, e.overtime_hours, e.vacation_days, e.sick_days, e.absent_days,
		        e.base_amount, e.piece_amount, e.bonus_amount, e.overtime_amount, e.vacation_amount,
		        e.deductions, e.gross_amount, e.net_amount,
		        (e.money_document_id IS NOT NULL), COALESCE(e.paid_at::text,''), e.notes
		 FROM payroll_entries e
		 JOIN employees emp ON emp.id = e.employee_id
		 WHERE e.period_id = $1::uuid
		 ORDER BY lower(emp.full_name) ASC`,
		periodID,
	)
	if err != nil {
		return PayrollPeriodDetail{}, err
	}
	defer rows.Close()

	detail.Entries = make([]PayrollEntry, 0)
	for rows.Next() {
		var e PayrollEntry
		var base, piece, bonus, overtime, vacation, deductions, gross, net float64
		if err := rows.Scan(
			&e.ID, &e.EmployeeID, &e.EmployeeName, &e.Position, &e.SalaryType,
			&e.DaysWorked, &e.HoursWorked, &e.OvertimeHours, &e.VacationDays, &e.SickDays, &e.AbsentDays,
			&base, &piece, &bonus, &overtime, &vacation, &deductions, &gross, &net,
			&e.IsPaid, &e.PaidAt, &e.Notes,
		); err != nil {
			return PayrollPeriodDetail{}, err
		}
		e.BaseAmount = int(base)
		e.PieceAmount = int(piece)
		e.BonusAmount = int(bonus)
		e.OvertimeAmount = int(overtime)
		e.VacationAmount = int(vacation)
		e.Deductions = int(deductions)
		e.GrossAmount = int(gross)
		e.NetAmount = int(net)
		detail.Entries = append(detail.Entries, e)
	}
	return detail, rows.Err()
}

func (s *PostgresStore) DeletePayrollPeriod(user auth.User, periodID string) error {
	ctx, cancel := s.withTimeout()
	defer cancel()

	companyID, err := s.ensurePrimaryCompany(ctx, user)
	if err != nil {
		return err
	}

	result, err := s.db.ExecContext(ctx,
		`DELETE FROM payroll_periods WHERE id=$1::uuid AND company_id=$2::uuid`,
		periodID, companyID,
	)
	if err != nil {
		return err
	}
	if affected, _ := result.RowsAffected(); affected == 0 {
		return fmt.Errorf("%w: payroll period not found", ErrValidation)
	}
	return nil
}

// ── Calculation ───────────────────────────────────────────────────────────────

func (s *PostgresStore) CalculatePayroll(user auth.User, periodID string) (PayrollPeriodDetail, error) {
	ctx, cancel := s.withTimeout()
	defer cancel()

	companyID, err := s.ensurePrimaryCompany(ctx, user)
	if err != nil {
		return PayrollPeriodDetail{}, err
	}

	var year, month int
	var status string
	err = s.db.QueryRowContext(ctx,
		`SELECT period_year, period_month, status FROM payroll_periods
		 WHERE id=$1::uuid AND company_id=$2::uuid`,
		periodID, companyID,
	).Scan(&year, &month, &status)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return PayrollPeriodDetail{}, fmt.Errorf("%w: payroll period not found", ErrValidation)
		}
		return PayrollPeriodDetail{}, err
	}
	if status == "paid" {
		return PayrollPeriodDetail{}, fmt.Errorf("%w: paid period cannot be recalculated", ErrValidation)
	}

	periodStart := fmt.Sprintf("%04d-%02d-01", year, month)
	endYear, endMonth := year, month+1
	if endMonth > 12 {
		endMonth = 1
		endYear++
	}
	periodEnd := fmt.Sprintf("%04d-%02d-01", endYear, endMonth)

	employees, err := s.ListEmployees(user)
	if err != nil {
		return PayrollPeriodDetail{}, err
	}

	for _, emp := range employees {
		if emp.Status != "active" {
			continue
		}

		// Preserve any manually entered timesheet / bonus / deductions for this entry.
		var (
			daysWorked, hoursWorked, overtimeHours, vacationDays, sickDays, absentDays float64
			bonusAmount, deductions                                                    float64
			notes                                                                      string
		)
		entryErr := s.db.QueryRowContext(ctx,
			`SELECT days_worked, hours_worked, overtime_hours, vacation_days, sick_days, absent_days,
			        bonus_amount, deductions, notes
			 FROM payroll_entries WHERE period_id=$1::uuid AND employee_id=$2::uuid`,
			periodID, emp.ID,
		).Scan(&daysWorked, &hoursWorked, &overtimeHours, &vacationDays, &sickDays, &absentDays,
			&bonusAmount, &deductions, &notes)
		if entryErr != nil && !errors.Is(entryErr, sql.ErrNoRows) {
			return PayrollPeriodDetail{}, entryErr
		}

		pieceAmount, err := s.aggregatePieceAmount(ctx, companyID, emp, periodStart, periodEnd)
		if err != nil {
			return PayrollPeriodDetail{}, err
		}

		base, overtime, vacation := computeBaseAmounts(emp, daysWorked, hoursWorked, overtimeHours, vacationDays)
		bonus := int(bonusAmount)
		ded := int(deductions)
		gross := base + pieceAmount + bonus + overtime + vacation
		net := gross - ded

		_, err = s.db.ExecContext(ctx,
			`INSERT INTO payroll_entries
			   (id, period_id, employee_id, days_worked, hours_worked, overtime_hours,
			    vacation_days, sick_days, absent_days, base_amount, piece_amount, bonus_amount,
			    overtime_amount, vacation_amount, deductions, gross_amount, net_amount, notes,
			    created_at, updated_at)
			 VALUES ($1::uuid, $2::uuid, $3::uuid, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, NOW(), NOW())
			 ON CONFLICT (period_id, employee_id) DO UPDATE SET
			   base_amount=EXCLUDED.base_amount, piece_amount=EXCLUDED.piece_amount,
			   overtime_amount=EXCLUDED.overtime_amount, vacation_amount=EXCLUDED.vacation_amount,
			   gross_amount=EXCLUDED.gross_amount, net_amount=EXCLUDED.net_amount, updated_at=NOW()`,
			mustGenerateProductID(), periodID, emp.ID, daysWorked, hoursWorked, overtimeHours,
			vacationDays, sickDays, absentDays, base, pieceAmount, bonus,
			overtime, vacation, ded, gross, net, notes,
		)
		if err != nil {
			return PayrollPeriodDetail{}, err
		}
	}

	if status == "draft" {
		if _, err := s.db.ExecContext(ctx,
			`UPDATE payroll_periods SET status='calculated', updated_at=NOW()
			 WHERE id=$1::uuid AND company_id=$2::uuid`,
			periodID, companyID,
		); err != nil {
			return PayrollPeriodDetail{}, err
		}
	}

	return s.loadPayrollPeriod(ctx, companyID, periodID)
}

// aggregatePieceAmount sums all rule-based piece earnings for the employee within
// the period: production participation (always), sales commission (if configured),
// and a legacy per-document purchases rate.
func (s *PostgresStore) aggregatePieceAmount(ctx context.Context, companyID string, emp Employee, periodStart string, periodEnd string) (int, error) {
	total := 0.0

	// Production: distribute each completed order's recipe payroll amount (× batches)
	// among its participants by their share. Applies to any participant.
	var productionShare float64
	if err := s.db.QueryRowContext(ctx,
		`SELECT COALESCE(SUM(r.payroll_amount * po.planned_quantity * pp.share_percent / 100), 0)
		 FROM production_order_participants pp
		 JOIN production_orders po ON po.id = pp.order_id
		 JOIN recipes r ON r.id = po.recipe_id
		 WHERE po.company_id=$1::uuid AND pp.employee_id=$2::uuid AND po.status='completed'
		   AND COALESCE(po.planned_date, po.created_at::date) >= $3::date
		   AND COALESCE(po.planned_date, po.created_at::date) < $4::date`,
		companyID, emp.ID, periodStart, periodEnd,
	).Scan(&productionShare); err != nil {
		return 0, err
	}
	total += productionShare

	// Sales commission: percent of revenue or profit on posted sale documents
	// where the employee is the salesperson.
	if emp.SalesPercent > 0 {
		var revenue, profit float64
		if err := s.db.QueryRowContext(ctx,
			`SELECT
			    COALESCE(SUM(l.quantity * l.unit_price), 0),
			    COALESCE(SUM(l.quantity * (l.unit_price - l.unit_cost)), 0)
			 FROM inventory_document_lines l
			 JOIN inventory_documents d ON d.id = l.document_id
			 WHERE d.company_id=$1::uuid AND d.employee_id=$2::uuid AND d.status='posted'
			   AND d.document_type='sale_issue'
			   AND d.document_date >= $3::date AND d.document_date < $4::date`,
			companyID, emp.ID, periodStart, periodEnd,
		).Scan(&revenue, &profit); err != nil {
			return 0, err
		}
		base := revenue
		if emp.SalesBasis == "profit" {
			base = profit
		}
		total += emp.SalesPercent / 100 * base
	}

	// Purchases (legacy, no UI): per-document rate when configured.
	if emp.PieceRateSource == "purchases" && emp.PieceRate > 0 {
		var count int
		if err := s.db.QueryRowContext(ctx,
			`SELECT COUNT(*)
			 FROM inventory_documents
			 WHERE company_id=$1::uuid AND employee_id=$2::uuid AND status='posted'
			   AND document_type='purchase_receipt'
			   AND document_date >= $3::date AND document_date < $4::date`,
			companyID, emp.ID, periodStart, periodEnd,
		).Scan(&count); err != nil {
			return 0, err
		}
		total += float64(count * emp.PieceRate)
	}

	if total < 0 {
		total = 0
	}
	return int(math.Round(total)), nil
}

// computeBaseAmounts derives base salary, overtime pay and vacation pay from the
// employee's salary type and the period timesheet summary.
func computeBaseAmounts(emp Employee, daysWorked, hoursWorked, overtimeHours, vacationDays float64) (base int, overtime int, vacation int) {
	standardDays := emp.StandardDays
	if standardDays <= 0 {
		standardDays = 22
	}

	switch emp.SalaryType {
	case "monthly", "combined":
		if daysWorked > 0 {
			base = int(math.Round(float64(emp.MonthlySalary) * daysWorked / float64(standardDays)))
		} else {
			base = emp.MonthlySalary
		}
	case "hourly":
		base = int(math.Round(float64(emp.HourlyRate) * hoursWorked))
	case "piece_rate", "bonus":
		base = 0
	}

	// Overtime: 1.5x of hourly-equivalent rate.
	hourlyEquiv := float64(emp.HourlyRate)
	if hourlyEquiv == 0 && emp.MonthlySalary > 0 {
		hourlyEquiv = float64(emp.MonthlySalary) / float64(standardDays) / 8.0
	}
	if overtimeHours > 0 && hourlyEquiv > 0 {
		overtime = int(math.Round(hourlyEquiv * overtimeHours * 1.5))
	}

	// Vacation pay: only for salaried employees (oklad).
	if vacationDays > 0 && emp.MonthlySalary > 0 &&
		(emp.SalaryType == "monthly" || emp.SalaryType == "combined") {
		vacation = int(math.Round(float64(emp.MonthlySalary) / float64(standardDays) * vacationDays))
	}
	return base, overtime, vacation
}

func (s *PostgresStore) UpdatePayrollEntry(user auth.User, periodID string, entryID string, input UpdatePayrollEntryInput) (PayrollPeriodDetail, error) {
	ctx, cancel := s.withTimeout()
	defer cancel()

	companyID, err := s.ensurePrimaryCompany(ctx, user)
	if err != nil {
		return PayrollPeriodDetail{}, err
	}

	normalized := NormalizeUpdatePayrollEntryInput(input)

	// Load the employee config behind this entry so amounts can be recomputed.
	var emp Employee
	var monthly, hourly, piece float64
	var pieceAmount float64
	var isPaid bool
	err = s.db.QueryRowContext(ctx,
		`SELECT emp.salary_type, emp.monthly_salary, emp.hourly_rate, emp.piece_rate,
		        emp.piece_rate_source, emp.standard_days, e.piece_amount,
		        (e.money_document_id IS NOT NULL)
		 FROM payroll_entries e
		 JOIN employees emp ON emp.id = e.employee_id
		 JOIN payroll_periods p ON p.id = e.period_id
		 WHERE e.id=$1::uuid AND e.period_id=$2::uuid AND p.company_id=$3::uuid`,
		entryID, periodID, companyID,
	).Scan(&emp.SalaryType, &monthly, &hourly, &piece, &emp.PieceRateSource, &emp.StandardDays, &pieceAmount, &isPaid)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return PayrollPeriodDetail{}, fmt.Errorf("%w: payroll entry not found", ErrValidation)
		}
		return PayrollPeriodDetail{}, err
	}
	if isPaid {
		return PayrollPeriodDetail{}, fmt.Errorf("%w: paid entry cannot be changed", ErrValidation)
	}
	emp.MonthlySalary = int(monthly)
	emp.HourlyRate = int(hourly)
	emp.PieceRate = int(piece)

	base, overtime, vacation := computeBaseAmounts(emp, normalized.DaysWorked, normalized.HoursWorked,
		normalized.OvertimeHours, normalized.VacationDays)
	gross := base + int(pieceAmount) + normalized.BonusAmount + overtime + vacation
	net := gross - normalized.Deductions

	_, err = s.db.ExecContext(ctx,
		`UPDATE payroll_entries SET
		   days_worked=$3, hours_worked=$4, overtime_hours=$5, vacation_days=$6, sick_days=$7, absent_days=$8,
		   base_amount=$9, bonus_amount=$10, overtime_amount=$11, vacation_amount=$12, deductions=$13,
		   gross_amount=$14, net_amount=$15, notes=$16, updated_at=NOW()
		 WHERE id=$1::uuid AND period_id=$2::uuid`,
		entryID, periodID, normalized.DaysWorked, normalized.HoursWorked, normalized.OvertimeHours,
		normalized.VacationDays, normalized.SickDays, normalized.AbsentDays,
		base, normalized.BonusAmount, overtime, vacation, normalized.Deductions, gross, net, normalized.Notes,
	)
	if err != nil {
		return PayrollPeriodDetail{}, err
	}

	return s.loadPayrollPeriod(ctx, companyID, periodID)
}

// ── Payment (posts salary expenses into finance) ──────────────────────────────

func (s *PostgresStore) PayPayrollPeriod(user auth.User, periodID string, input PayPayrollPeriodInput) (PayrollPeriodDetail, error) {
	ctx, cancel := s.withTimeout()
	defer cancel()

	companyID, err := s.ensurePrimaryCompany(ctx, user)
	if err != nil {
		return PayrollPeriodDetail{}, err
	}

	if err := ValidatePayPayrollPeriodInput(input); err != nil {
		return PayrollPeriodDetail{}, err
	}

	operationDate := time.Now()
	if input.OperationDate != "" {
		operationDate, err = time.Parse("2006-01-02", input.OperationDate)
		if err != nil {
			return PayrollPeriodDetail{}, fmt.Errorf("%w: operation date must be in YYYY-MM-DD format", ErrValidation)
		}
	}

	var periodTitle string
	if err := s.db.QueryRowContext(ctx,
		`SELECT title FROM payroll_periods WHERE id=$1::uuid AND company_id=$2::uuid`,
		periodID, companyID,
	).Scan(&periodTitle); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return PayrollPeriodDetail{}, fmt.Errorf("%w: payroll period not found", ErrValidation)
		}
		return PayrollPeriodDetail{}, err
	}

	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return PayrollPeriodDetail{}, err
	}
	defer func() {
		if err != nil {
			_ = tx.Rollback()
		}
	}()

	account, err := s.findCashAccount(ctx, tx, companyID, input.AccountID)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return PayrollPeriodDetail{}, fmt.Errorf("%w: account not found", ErrValidation)
		}
		return PayrollPeriodDetail{}, err
	}

	categoryID, err := s.ensureMoneyCategory(ctx, tx, companyID, "expense", "Зарплата")
	if err != nil {
		return PayrollPeriodDetail{}, err
	}

	rows, err := tx.QueryContext(ctx,
		`SELECT e.id::text, emp.full_name, e.net_amount
		 FROM payroll_entries e
		 JOIN employees emp ON emp.id = e.employee_id
		 WHERE e.period_id=$1::uuid AND e.money_document_id IS NULL AND e.net_amount > 0`,
		periodID,
	)
	if err != nil {
		return PayrollPeriodDetail{}, err
	}

	type pendingEntry struct {
		id     string
		name   string
		amount int
	}
	var pending []pendingEntry
	for rows.Next() {
		var pe pendingEntry
		var amount float64
		if err = rows.Scan(&pe.id, &pe.name, &amount); err != nil {
			rows.Close()
			return PayrollPeriodDetail{}, err
		}
		pe.amount = int(amount)
		pending = append(pending, pe)
	}
	if err = rows.Err(); err != nil {
		rows.Close()
		return PayrollPeriodDetail{}, err
	}
	rows.Close()

	if len(pending) == 0 {
		return PayrollPeriodDetail{}, fmt.Errorf("%w: nothing to pay", ErrValidation)
	}

	balance := account.Balance
	for _, pe := range pending {
		description := fmt.Sprintf("Зарплата: %s (%s)", pe.name, periodTitle)
		documentNo := s.nextMoneyDocumentNo("expense")

		var documentID string
		if err = tx.QueryRowContext(ctx,
			`INSERT INTO money_documents (
			   company_id, document_no, document_type, status, operation_date,
			   primary_account_id, description, created_by_user_id, posted_by_user_id, posted_at, created_at, updated_at
			 ) VALUES (
			   $1::uuid, $2, 'salary', 'posted', $3, $4::uuid, $5, $6, $6, NOW(), NOW(), NOW()
			 ) RETURNING id::text`,
			companyID, documentNo, operationDate.Format("2006-01-02"), account.ID, description, user.ID,
		).Scan(&documentID); err != nil {
			return PayrollPeriodDetail{}, err
		}

		var lineID string
		if err = tx.QueryRowContext(ctx,
			`INSERT INTO money_document_lines (document_id, line_no, category_id, amount, note, created_at)
			 VALUES ($1::uuid, 1, $2::uuid, $3, $4, NOW())
			 RETURNING id::text`,
			documentID, nullUUID(categoryID), pe.amount, description,
		).Scan(&lineID); err != nil {
			return PayrollPeriodDetail{}, err
		}

		balance -= pe.amount
		if err = s.insertMoneyMovement(ctx, tx, companyID, account.ID, documentID, lineID, "", categoryID, "",
			"expense", pe.amount, -pe.amount, balance, operationDate); err != nil {
			return PayrollPeriodDetail{}, err
		}

		if _, err = tx.ExecContext(ctx,
			`UPDATE payroll_entries SET money_document_id=$2::uuid, paid_at=NOW(), updated_at=NOW()
			 WHERE id=$1::uuid`,
			pe.id, documentID,
		); err != nil {
			return PayrollPeriodDetail{}, err
		}
	}

	if err = s.upsertCashAccountBalance(ctx, tx, account.ID, balance); err != nil {
		return PayrollPeriodDetail{}, err
	}

	if _, err = tx.ExecContext(ctx,
		`UPDATE payroll_periods SET status='paid', updated_at=NOW()
		 WHERE id=$1::uuid AND company_id=$2::uuid`,
		periodID, companyID,
	); err != nil {
		return PayrollPeriodDetail{}, err
	}

	if err = tx.Commit(); err != nil {
		return PayrollPeriodDetail{}, err
	}

	return s.loadPayrollPeriod(ctx, companyID, periodID)
}
