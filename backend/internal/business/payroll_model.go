package business

import (
	"fmt"
	"strings"
	"time"
)

// ── Employees ─────────────────────────────────────────────────────────────────

// Employee is one company employee in the payroll directory. Monetary fields are
// whole tenge (int), matching the rest of the money models.
type Employee struct {
	ID              string  `json:"id"`
	FullName        string  `json:"full_name"`
	Position        string  `json:"position"`
	IIN             string  `json:"iin,omitempty"`
	Phone           string  `json:"phone,omitempty"`
	SalaryType      string  `json:"salary_type"`
	MonthlySalary   int     `json:"monthly_salary"`
	HourlyRate      int     `json:"hourly_rate"`
	PieceRate       int     `json:"piece_rate"`
	PieceRateSource string  `json:"piece_rate_source"`
	SalesPercent    float64 `json:"sales_percent"`
	SalesBasis      string  `json:"sales_basis"`
	StandardDays    int     `json:"standard_days"`
	HireDate        string  `json:"hire_date,omitempty"`
	Status          string  `json:"status"`
	Notes           string  `json:"notes,omitempty"`
}

type CreateEmployeeInput struct {
	FullName        string  `json:"full_name"`
	Position        string  `json:"position"`
	IIN             string  `json:"iin"`
	Phone           string  `json:"phone"`
	SalaryType      string  `json:"salary_type"`
	MonthlySalary   int     `json:"monthly_salary"`
	HourlyRate      int     `json:"hourly_rate"`
	PieceRate       int     `json:"piece_rate"`
	PieceRateSource string  `json:"piece_rate_source"`
	SalesPercent    float64 `json:"sales_percent"`
	SalesBasis      string  `json:"sales_basis"`
	StandardDays    int     `json:"standard_days"`
	HireDate        string  `json:"hire_date"`
	Status          string  `json:"status"`
	Notes           string  `json:"notes"`
}

func NormalizeEmployeeInput(input CreateEmployeeInput) CreateEmployeeInput {
	input.FullName = strings.Join(strings.Fields(input.FullName), " ")
	input.Position = strings.TrimSpace(input.Position)
	input.IIN = normalizeDigits(input.IIN)
	input.Phone = normalizePhone(input.Phone)
	input.SalaryType = strings.TrimSpace(strings.ToLower(input.SalaryType))
	input.PieceRateSource = strings.TrimSpace(strings.ToLower(input.PieceRateSource))
	input.SalesBasis = strings.TrimSpace(strings.ToLower(input.SalesBasis))
	input.Status = strings.TrimSpace(strings.ToLower(input.Status))
	input.HireDate = strings.TrimSpace(input.HireDate)
	input.Notes = strings.TrimSpace(input.Notes)

	if input.SalaryType == "" {
		input.SalaryType = "monthly"
	}
	if input.PieceRateSource == "" {
		input.PieceRateSource = "none"
	}
	if input.SalesBasis == "" {
		input.SalesBasis = "revenue"
	}
	if input.SalesPercent < 0 {
		input.SalesPercent = 0
	}
	if input.SalesPercent > 100 {
		input.SalesPercent = 100
	}
	if input.Status == "" {
		input.Status = "active"
	}
	if input.StandardDays <= 0 {
		input.StandardDays = 22
	}
	return input
}

func ValidateEmployeeInput(input CreateEmployeeInput) error {
	if len([]rune(input.FullName)) < 2 || len([]rune(input.FullName)) > 160 {
		return fmt.Errorf("%w: employee full name must be between 2 and 160 characters", ErrValidation)
	}
	switch input.SalaryType {
	case "monthly", "hourly", "piece_rate", "bonus", "combined":
	default:
		return fmt.Errorf("%w: salary type is invalid", ErrValidation)
	}
	switch input.PieceRateSource {
	case "none", "production", "sales", "purchases":
	default:
		return fmt.Errorf("%w: piece rate source is invalid", ErrValidation)
	}
	switch input.SalesBasis {
	case "revenue", "profit":
	default:
		return fmt.Errorf("%w: sales basis is invalid", ErrValidation)
	}
	if input.SalesPercent < 0 || input.SalesPercent > 100 {
		return fmt.Errorf("%w: sales percent must be between 0 and 100", ErrValidation)
	}
	switch input.Status {
	case "active", "inactive":
	default:
		return fmt.Errorf("%w: status is invalid", ErrValidation)
	}
	if input.IIN != "" && len(input.IIN) != 12 {
		return fmt.Errorf("%w: IIN must contain 12 digits", ErrValidation)
	}
	if input.MonthlySalary < 0 || input.HourlyRate < 0 || input.PieceRate < 0 {
		return fmt.Errorf("%w: rates must be zero or greater", ErrValidation)
	}
	if input.StandardDays < 1 || input.StandardDays > 31 {
		return fmt.Errorf("%w: standard days must be between 1 and 31", ErrValidation)
	}
	if (input.SalaryType == "piece_rate" || input.SalaryType == "combined") &&
		input.PieceRate > 0 && input.PieceRateSource == "none" {
		return fmt.Errorf("%w: piece rate source is required for piece rate", ErrValidation)
	}
	if input.HireDate != "" {
		if _, err := time.Parse("2006-01-02", input.HireDate); err != nil {
			return fmt.Errorf("%w: hire date must be in YYYY-MM-DD format", ErrValidation)
		}
	}
	return nil
}

// ── Payroll periods & entries ─────────────────────────────────────────────────

type PayrollPeriod struct {
	ID            string `json:"id"`
	PeriodYear    int    `json:"period_year"`
	PeriodMonth   int    `json:"period_month"`
	Title         string `json:"title"`
	Status        string `json:"status"`
	CreatedAt     string `json:"created_at"`
	EmployeeCount int    `json:"employee_count"`
	TotalNet      int    `json:"total_net"`
	PaidCount     int    `json:"paid_count"`
}

type CreatePayrollPeriodInput struct {
	PeriodYear  int    `json:"period_year"`
	PeriodMonth int    `json:"period_month"`
	Title       string `json:"title"`
}

type PayrollEntry struct {
	ID             string  `json:"id"`
	EmployeeID     string  `json:"employee_id"`
	EmployeeName   string  `json:"employee_name"`
	Position       string  `json:"position"`
	SalaryType     string  `json:"salary_type"`
	DaysWorked     float64 `json:"days_worked"`
	HoursWorked    float64 `json:"hours_worked"`
	OvertimeHours  float64 `json:"overtime_hours"`
	VacationDays   float64 `json:"vacation_days"`
	SickDays       float64 `json:"sick_days"`
	AbsentDays     float64 `json:"absent_days"`
	BaseAmount     int     `json:"base_amount"`
	PieceAmount    int     `json:"piece_amount"`
	BonusAmount    int     `json:"bonus_amount"`
	OvertimeAmount int     `json:"overtime_amount"`
	VacationAmount int     `json:"vacation_amount"`
	Deductions     int     `json:"deductions"`
	GrossAmount    int     `json:"gross_amount"`
	NetAmount      int     `json:"net_amount"`
	IsPaid         bool    `json:"is_paid"`
	PaidAt         string  `json:"paid_at,omitempty"`
	Notes          string  `json:"notes,omitempty"`
}

type PayrollPeriodDetail struct {
	Period  PayrollPeriod  `json:"period"`
	Entries []PayrollEntry `json:"entries"`
}

type EmployeeStatementEntry struct {
	PeriodYear     int     `json:"period_year"`
	PeriodMonth    int     `json:"period_month"`
	Title          string  `json:"title"`
	Status         string  `json:"status"`
	DaysWorked     float64 `json:"days_worked"`
	HoursWorked    float64 `json:"hours_worked"`
	BaseAmount     int     `json:"base_amount"`
	PieceAmount    int     `json:"piece_amount"`
	BonusAmount    int     `json:"bonus_amount"`
	OvertimeAmount int     `json:"overtime_amount"`
	VacationAmount int     `json:"vacation_amount"`
	Deductions     int     `json:"deductions"`
	GrossAmount    int     `json:"gross_amount"`
	NetAmount      int     `json:"net_amount"`
	IsPaid         bool    `json:"is_paid"`
	PaidAt         string  `json:"paid_at,omitempty"`
}

type EmployeeStatement struct {
	EmployeeID     string                   `json:"employee_id"`
	EmployeeName   string                   `json:"employee_name"`
	Position       string                   `json:"position"`
	From           string                   `json:"from"`
	To             string                   `json:"to"`
	TotalBase      int                      `json:"total_base"`
	TotalPiece     int                      `json:"total_piece"`
	TotalBonus     int                      `json:"total_bonus"`
	TotalOvertime  int                      `json:"total_overtime"`
	TotalVacation  int                      `json:"total_vacation"`
	TotalDeductions int                     `json:"total_deductions"`
	TotalGross     int                      `json:"total_gross"`
	TotalNet       int                      `json:"total_net"`
	TotalPaid      int                      `json:"total_paid"`
	Entries        []EmployeeStatementEntry `json:"entries"`
}

type UpdatePayrollEntryInput struct {
	DaysWorked    float64 `json:"days_worked"`
	HoursWorked   float64 `json:"hours_worked"`
	OvertimeHours float64 `json:"overtime_hours"`
	VacationDays  float64 `json:"vacation_days"`
	SickDays      float64 `json:"sick_days"`
	AbsentDays    float64 `json:"absent_days"`
	BonusAmount   int     `json:"bonus_amount"`
	Deductions    int     `json:"deductions"`
	Notes         string  `json:"notes"`
}

type PayPayrollPeriodInput struct {
	AccountID     string `json:"account_id"`
	OperationDate string `json:"operation_date"`
}

func NormalizePayrollPeriodInput(input CreatePayrollPeriodInput) CreatePayrollPeriodInput {
	input.Title = strings.TrimSpace(input.Title)
	if input.PeriodYear == 0 || input.PeriodMonth == 0 {
		now := time.Now()
		if input.PeriodYear == 0 {
			input.PeriodYear = now.Year()
		}
		if input.PeriodMonth == 0 {
			input.PeriodMonth = int(now.Month())
		}
	}
	if input.Title == "" {
		input.Title = fmt.Sprintf("%s %d", monthNameRu(input.PeriodMonth), input.PeriodYear)
	}
	return input
}

func ValidatePayrollPeriodInput(input CreatePayrollPeriodInput) error {
	if input.PeriodMonth < 1 || input.PeriodMonth > 12 {
		return fmt.Errorf("%w: period month must be between 1 and 12", ErrValidation)
	}
	if input.PeriodYear < 2000 || input.PeriodYear > 2200 {
		return fmt.Errorf("%w: period year is invalid", ErrValidation)
	}
	return nil
}

func NormalizeUpdatePayrollEntryInput(input UpdatePayrollEntryInput) UpdatePayrollEntryInput {
	input.Notes = strings.TrimSpace(input.Notes)
	input.DaysWorked = clampNonNegativeFloat(input.DaysWorked)
	input.HoursWorked = clampNonNegativeFloat(input.HoursWorked)
	input.OvertimeHours = clampNonNegativeFloat(input.OvertimeHours)
	input.VacationDays = clampNonNegativeFloat(input.VacationDays)
	input.SickDays = clampNonNegativeFloat(input.SickDays)
	input.AbsentDays = clampNonNegativeFloat(input.AbsentDays)
	if input.BonusAmount < 0 {
		input.BonusAmount = 0
	}
	if input.Deductions < 0 {
		input.Deductions = 0
	}
	return input
}

func ValidatePayPayrollPeriodInput(input PayPayrollPeriodInput) error {
	if strings.TrimSpace(input.AccountID) == "" {
		return fmt.Errorf("%w: account id is required", ErrValidation)
	}
	if strings.TrimSpace(input.OperationDate) != "" {
		if _, err := time.Parse("2006-01-02", input.OperationDate); err != nil {
			return fmt.Errorf("%w: operation date must be in YYYY-MM-DD format", ErrValidation)
		}
	}
	return nil
}

func clampNonNegativeFloat(value float64) float64 {
	if value < 0 {
		return 0
	}
	return value
}

func monthNameRu(month int) string {
	names := []string{
		"Январь", "Февраль", "Март", "Апрель", "Май", "Июнь",
		"Июль", "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь",
	}
	if month < 1 || month > 12 {
		return "Период"
	}
	return names[month-1]
}
