package business

import "strings"

const (
	permCompanySettingsRead  = "company.settings.read"
	permCompanySettingsWrite = "company.settings.write"
	permCompanyMembersRead   = "company.members.read"
	permCompanyMembersWrite  = "company.members.write"
	permCRMRead              = "crm.read"
	permCRMWrite             = "crm.write"
	permWarehouseRead        = "warehouse.read"
	permWarehouseWrite       = "warehouse.write"
	permFinanceRead          = "finance.read"
	permFinanceWrite         = "finance.write"
	permCatalogRead          = "catalog.read"
	permCatalogWrite         = "catalog.write"
	permProductionRead       = "production.read"
	permProductionWrite      = "production.write"
	permPayrollRead          = "payroll.read"
	permPayrollWrite         = "payroll.write"
)

func hasPermission(role string, permission string) bool {
	switch strings.TrimSpace(strings.ToLower(role)) {
	case "owner", "admin":
		return true
	case "manager":
		switch permission {
		case permCRMRead, permCRMWrite, permCatalogRead, permCatalogWrite,
			permWarehouseRead, permFinanceRead, permProductionRead:
			return true
		}
	case "accountant":
		switch permission {
		case permFinanceRead, permFinanceWrite, permCRMRead, permPayrollRead, permPayrollWrite:
			return true
		}
	case "warehouse":
		switch permission {
		case permWarehouseRead, permWarehouseWrite, permCatalogRead:
			return true
		}
	case "sales":
		switch permission {
		case permCRMRead, permCRMWrite, permCatalogRead, permWarehouseRead:
			return true
		}
	case "staff":
		return false
	}
	return false
}
