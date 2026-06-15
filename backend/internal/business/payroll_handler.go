package business

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"

	"github.com/altyncloud/saas-uchet/backend/internal/auth"
	"github.com/altyncloud/saas-uchet/backend/internal/response"
)

// Employees handles /api/v1/payroll/employees (list, create).
func (h Handler) Employees(w http.ResponseWriter, r *http.Request) {
	user, ok := h.authorize(w, r)
	if !ok {
		return
	}
	permission := permPayrollRead
	if r.Method != http.MethodGet {
		permission = permPayrollWrite
	}
	if !h.requireActiveCompanyPermission(w, user, permission) {
		return
	}

	switch r.Method {
	case http.MethodGet:
		employees, err := h.store.ListEmployees(user)
		if err != nil {
			response.Error(w, http.StatusInternalServerError, "internal server error")
			return
		}
		response.JSON(w, http.StatusOK, map[string]any{"employees": employees})
	case http.MethodPost:
		var input CreateEmployeeInput
		if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
			response.Error(w, http.StatusBadRequest, "invalid request body")
			return
		}
		employee, err := h.store.CreateEmployee(user, input)
		if err != nil {
			if errors.Is(err, ErrValidation) {
				response.Error(w, http.StatusBadRequest, err.Error())
				return
			}
			response.Error(w, http.StatusInternalServerError, "internal server error")
			return
		}
		response.JSON(w, http.StatusCreated, employee)
	default:
		response.Error(w, http.StatusMethodNotAllowed, "method not allowed")
	}
}

// EmployeeByID handles /api/v1/payroll/employees/{id} (update, delete).
func (h Handler) EmployeeByID(w http.ResponseWriter, r *http.Request) {
	user, ok := h.authorize(w, r)
	if !ok {
		return
	}

	employeeID := strings.TrimSpace(strings.TrimPrefix(r.URL.Path, "/api/v1/payroll/employees/"))
	if employeeID == "" || strings.Contains(employeeID, "/") {
		response.Error(w, http.StatusNotFound, "employee not found")
		return
	}
	if !h.requireActiveCompanyPermission(w, user, permPayrollWrite) {
		return
	}

	switch r.Method {
	case http.MethodPut:
		var input CreateEmployeeInput
		if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
			response.Error(w, http.StatusBadRequest, "invalid request body")
			return
		}
		employee, err := h.store.UpdateEmployee(user, employeeID, input)
		if err != nil {
			if errors.Is(err, ErrValidation) {
				response.Error(w, http.StatusBadRequest, err.Error())
				return
			}
			response.Error(w, http.StatusInternalServerError, "internal server error")
			return
		}
		response.JSON(w, http.StatusOK, employee)
	case http.MethodDelete:
		if err := h.store.DeleteEmployee(user, employeeID); err != nil {
			if errors.Is(err, ErrValidation) {
				response.Error(w, http.StatusNotFound, "employee not found")
				return
			}
			response.Error(w, http.StatusInternalServerError, "internal server error")
			return
		}
		w.WriteHeader(http.StatusNoContent)
	default:
		response.Error(w, http.StatusMethodNotAllowed, "method not allowed")
	}
}

// PayrollPeriods handles /api/v1/payroll/periods (list, create).
func (h Handler) PayrollPeriods(w http.ResponseWriter, r *http.Request) {
	user, ok := h.authorize(w, r)
	if !ok {
		return
	}
	permission := permPayrollRead
	if r.Method != http.MethodGet {
		permission = permPayrollWrite
	}
	if !h.requireActiveCompanyPermission(w, user, permission) {
		return
	}

	switch r.Method {
	case http.MethodGet:
		periods, err := h.store.ListPayrollPeriods(user)
		if err != nil {
			response.Error(w, http.StatusInternalServerError, "internal server error")
			return
		}
		response.JSON(w, http.StatusOK, map[string]any{"periods": periods})
	case http.MethodPost:
		var input CreatePayrollPeriodInput
		if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
			response.Error(w, http.StatusBadRequest, "invalid request body")
			return
		}
		period, err := h.store.CreatePayrollPeriod(user, input)
		if err != nil {
			if errors.Is(err, ErrValidation) {
				response.Error(w, http.StatusBadRequest, err.Error())
				return
			}
			response.Error(w, http.StatusInternalServerError, "internal server error")
			return
		}
		response.JSON(w, http.StatusCreated, period)
	default:
		response.Error(w, http.StatusMethodNotAllowed, "method not allowed")
	}
}

// PayrollPeriodByID handles /api/v1/payroll/periods/{id} and its sub-actions:
//
//	GET    /periods/{id}                       → detail
//	DELETE /periods/{id}                       → delete
//	POST   /periods/{id}/calculate             → (re)calculate entries
//	POST   /periods/{id}/pay                   → post salary expenses to finance
//	PUT    /periods/{id}/entries/{entryId}     → edit one entry's timesheet
func (h Handler) PayrollPeriodByID(w http.ResponseWriter, r *http.Request) {
	user, ok := h.authorize(w, r)
	if !ok {
		return
	}

	rest := strings.TrimSpace(strings.TrimPrefix(r.URL.Path, "/api/v1/payroll/periods/"))
	if rest == "" {
		response.Error(w, http.StatusNotFound, "payroll period not found")
		return
	}

	parts := strings.Split(rest, "/")
	periodID := parts[0]
	action := ""
	entryID := ""
	if len(parts) > 1 {
		action = parts[1]
	}
	if len(parts) > 2 {
		entryID = parts[2]
	}
	if periodID == "" {
		response.Error(w, http.StatusNotFound, "payroll period not found")
		return
	}

	switch action {
	case "":
		h.payrollPeriodRoot(w, r, user, periodID)
	case "calculate":
		h.payrollPeriodCalculate(w, r, user, periodID)
	case "pay":
		h.payrollPeriodPay(w, r, user, periodID)
	case "entries":
		h.payrollEntryUpdate(w, r, user, periodID, entryID)
	default:
		response.Error(w, http.StatusNotFound, "not found")
	}
}

func (h Handler) payrollPeriodRoot(w http.ResponseWriter, r *http.Request, user auth.User, periodID string) {
	switch r.Method {
	case http.MethodGet:
		if !h.requireActiveCompanyPermission(w, user, permPayrollRead) {
			return
		}
		detail, err := h.store.GetPayrollPeriod(user, periodID)
		if err != nil {
			response.Error(w, http.StatusNotFound, "payroll period not found")
			return
		}
		response.JSON(w, http.StatusOK, detail)
	case http.MethodDelete:
		if !h.requireActiveCompanyPermission(w, user, permPayrollWrite) {
			return
		}
		if err := h.store.DeletePayrollPeriod(user, periodID); err != nil {
			response.Error(w, http.StatusNotFound, "payroll period not found")
			return
		}
		w.WriteHeader(http.StatusNoContent)
	default:
		response.Error(w, http.StatusMethodNotAllowed, "method not allowed")
	}
}

func (h Handler) payrollPeriodCalculate(w http.ResponseWriter, r *http.Request, user auth.User, periodID string) {
	if r.Method != http.MethodPost {
		response.Error(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	if !h.requireActiveCompanyPermission(w, user, permPayrollWrite) {
		return
	}
	detail, err := h.store.CalculatePayroll(user, periodID)
	if err != nil {
		if errors.Is(err, ErrValidation) {
			response.Error(w, http.StatusBadRequest, err.Error())
			return
		}
		response.Error(w, http.StatusInternalServerError, "internal server error")
		return
	}
	response.JSON(w, http.StatusOK, detail)
}

func (h Handler) payrollPeriodPay(w http.ResponseWriter, r *http.Request, user auth.User, periodID string) {
	if r.Method != http.MethodPost {
		response.Error(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	if !h.requireActiveCompanyPermission(w, user, permPayrollWrite) {
		return
	}
	var input PayPayrollPeriodInput
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		response.Error(w, http.StatusBadRequest, "invalid request body")
		return
	}
	detail, err := h.store.PayPayrollPeriod(user, periodID, input)
	if err != nil {
		if errors.Is(err, ErrValidation) {
			response.Error(w, http.StatusBadRequest, err.Error())
			return
		}
		response.Error(w, http.StatusInternalServerError, "internal server error")
		return
	}
	response.JSON(w, http.StatusOK, detail)
}

func (h Handler) payrollEntryUpdate(w http.ResponseWriter, r *http.Request, user auth.User, periodID string, entryID string) {
	if r.Method != http.MethodPut {
		response.Error(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	if entryID == "" {
		response.Error(w, http.StatusNotFound, "payroll entry not found")
		return
	}
	if !h.requireActiveCompanyPermission(w, user, permPayrollWrite) {
		return
	}
	var input UpdatePayrollEntryInput
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		response.Error(w, http.StatusBadRequest, "invalid request body")
		return
	}
	detail, err := h.store.UpdatePayrollEntry(user, periodID, entryID, input)
	if err != nil {
		if errors.Is(err, ErrValidation) {
			response.Error(w, http.StatusBadRequest, err.Error())
			return
		}
		response.Error(w, http.StatusInternalServerError, "internal server error")
		return
	}
	response.JSON(w, http.StatusOK, detail)
}
