package business

import (
	"errors"
	"testing"
)

func TestValidateEmployeeInput(t *testing.T) {
	t.Parallel()

	base := CreateEmployeeInput{
		FullName:     "Иванов Иван",
		SalaryType:   "monthly",
		StandardDays: 22,
		Status:       "active",
	}

	tests := []struct {
		name    string
		mutate  func(CreateEmployeeInput) CreateEmployeeInput
		wantErr bool
	}{
		{
			name:   "valid monthly",
			mutate: func(in CreateEmployeeInput) CreateEmployeeInput { return in },
		},
		{
			name: "empty name",
			mutate: func(in CreateEmployeeInput) CreateEmployeeInput {
				in.FullName = ""
				return in
			},
			wantErr: true,
		},
		{
			name: "invalid salary type",
			mutate: func(in CreateEmployeeInput) CreateEmployeeInput {
				in.SalaryType = "weird"
				return in
			},
			wantErr: true,
		},
		{
			name: "bad iin length",
			mutate: func(in CreateEmployeeInput) CreateEmployeeInput {
				in.IIN = "123"
				return in
			},
			wantErr: true,
		},
		{
			name: "piece rate without source",
			mutate: func(in CreateEmployeeInput) CreateEmployeeInput {
				in.SalaryType = "piece_rate"
				in.PieceRate = 500
				in.PieceRateSource = "none"
				return in
			},
			wantErr: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			input := NormalizeEmployeeInput(tc.mutate(base))
			err := ValidateEmployeeInput(input)
			if tc.wantErr && err == nil {
				t.Fatalf("expected error, got nil")
			}
			if !tc.wantErr && err != nil {
				t.Fatalf("unexpected error: %v", err)
			}
			if tc.wantErr && err != nil && !errors.Is(err, ErrValidation) {
				t.Fatalf("expected ErrValidation, got %v", err)
			}
		})
	}
}

func TestComputeBaseAmounts(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name         string
		emp          Employee
		days         float64
		hours        float64
		overtime     float64
		vacationDays float64
		wantBase     int
		wantOvertime int
		wantVacation int
	}{
		{
			name:     "monthly full month",
			emp:      Employee{SalaryType: "monthly", MonthlySalary: 220000, StandardDays: 22},
			wantBase: 220000,
		},
		{
			name:     "monthly partial days prorates",
			emp:      Employee{SalaryType: "monthly", MonthlySalary: 220000, StandardDays: 22},
			days:     11,
			wantBase: 110000,
		},
		{
			name:     "hourly by hours",
			emp:      Employee{SalaryType: "hourly", HourlyRate: 2000, StandardDays: 22},
			hours:    100,
			wantBase: 200000,
		},
		{
			name:         "monthly with vacation pay",
			emp:          Employee{SalaryType: "monthly", MonthlySalary: 220000, StandardDays: 22},
			vacationDays: 2,
			wantBase:     220000,
			wantVacation: 20000,
		},
		{
			name:         "hourly overtime 1.5x",
			emp:          Employee{SalaryType: "hourly", HourlyRate: 2000, StandardDays: 22},
			hours:        0,
			overtime:     10,
			wantBase:     0,
			wantOvertime: 30000,
		},
		{
			name:     "piece rate has no base",
			emp:      Employee{SalaryType: "piece_rate", PieceRate: 500, StandardDays: 22},
			wantBase: 0,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			base, overtime, vacation := computeBaseAmounts(tc.emp, tc.days, tc.hours, tc.overtime, tc.vacationDays)
			if base != tc.wantBase {
				t.Errorf("base = %d, want %d", base, tc.wantBase)
			}
			if overtime != tc.wantOvertime {
				t.Errorf("overtime = %d, want %d", overtime, tc.wantOvertime)
			}
			if vacation != tc.wantVacation {
				t.Errorf("vacation = %d, want %d", vacation, tc.wantVacation)
			}
		})
	}
}
