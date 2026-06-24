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
	permSalesWrite           = "sales.write"
	permFinanceRead          = "finance.read"
	permFinanceWrite         = "finance.write"
	permCatalogRead          = "catalog.read"
	permCatalogWrite         = "catalog.write"
	permProductionRead       = "production.read"
	permProductionWrite      = "production.write"
	permPayrollRead          = "payroll.read"
	permPayrollWrite         = "payroll.write"
)

var allBusinessPermissions = []string{
	permCompanySettingsRead,
	permCompanySettingsWrite,
	permCompanyMembersRead,
	permCompanyMembersWrite,
	permCRMRead,
	permCRMWrite,
	permWarehouseRead,
	permWarehouseWrite,
	permSalesWrite,
	permFinanceRead,
	permFinanceWrite,
	permCatalogRead,
	permCatalogWrite,
	permProductionRead,
	permProductionWrite,
	permPayrollRead,
	permPayrollWrite,
}

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
		case permCRMRead, permCRMWrite, permCatalogRead, permWarehouseRead, permSalesWrite:
			return true
		}
	case "staff":
		return false
	}
	return false
}

// canWriteInventoryDocument decides whether a role may create/edit/post/delete
// an inventory document of the given type. Roles with full warehouse.write may
// touch every document type; a role that only has sales.write (e.g. sales) is
// limited to sale_issue documents.
func canWriteInventoryDocument(role string, documentType string) bool {
	if hasPermission(role, permWarehouseWrite) {
		return true
	}
	if documentType == "sale_issue" && hasPermission(role, permSalesWrite) {
		return true
	}
	return false
}

func permissionsForRole(role string) []string {
	permissions := make([]string, 0, len(allBusinessPermissions))
	for _, permission := range allBusinessPermissions {
		if hasPermission(role, permission) {
			permissions = append(permissions, permission)
		}
	}
	return permissions
}
