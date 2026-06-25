package transporthttp

import (
	stdhttp "net/http"

	"github.com/altyncloud/saas-uchet/backend/internal/auth"
	"github.com/altyncloud/saas-uchet/backend/internal/business"
	"github.com/altyncloud/saas-uchet/backend/internal/config"
	"github.com/altyncloud/saas-uchet/backend/internal/health"
	"github.com/altyncloud/saas-uchet/backend/internal/response"
)

func NewRouter(cfg config.Config, authHandler auth.Handler, businessHandler business.Handler) stdhttp.Handler {
	mux := stdhttp.NewServeMux()
	healthHandler := health.NewHandler(cfg.AppName, cfg.AppVersion)

	mux.HandleFunc("/", func(w stdhttp.ResponseWriter, r *stdhttp.Request) {
		if r.URL.Path != "/" {
			response.Error(w, stdhttp.StatusNotFound, "not found")
			return
		}

		if r.Method != stdhttp.MethodGet {
			response.Error(w, stdhttp.StatusMethodNotAllowed, "method not allowed")
			return
		}

		response.JSON(w, stdhttp.StatusOK, map[string]string{
			"service": cfg.AppName,
			"message": "API is ready",
		})
	})

	mux.HandleFunc("/api/v1/health", healthHandler.Get)
	mux.HandleFunc("/api/v1/auth/register", authHandler.Register)
	mux.HandleFunc("/api/v1/auth/login", authHandler.Login)
	mux.HandleFunc("/api/v1/auth/me", authHandler.Me)
	mux.HandleFunc("/api/v1/profile", authHandler.Profile)
	mux.HandleFunc("/api/v1/business/overview", businessHandler.Overview)
	mux.HandleFunc("/api/v1/business/clients", businessHandler.Clients)
	mux.HandleFunc("/api/v1/business/clients/", businessHandler.ClientByID)
	mux.HandleFunc("/api/v1/business/warehouses", businessHandler.Warehouses)
	mux.HandleFunc("/api/v1/business/warehouses/", businessHandler.WarehouseByID)
	mux.HandleFunc("/api/v1/business/products", businessHandler.Products)
	mux.HandleFunc("/api/v1/business/products/", businessHandler.ProductByID)
	mux.HandleFunc("/api/v1/business/inventory-documents", businessHandler.InventoryDocuments)
	mux.HandleFunc("/api/v1/business/inventory-documents/", businessHandler.InventoryDocumentByID)
	mux.HandleFunc("/api/v1/business/accounts", businessHandler.Accounts)
	mux.HandleFunc("/api/v1/business/money-operations", businessHandler.MoneyOperations)
	mux.HandleFunc("/api/v1/business/money-documents", businessHandler.MoneyDocuments)
	mux.HandleFunc("/api/v1/business/money-documents/", businessHandler.MoneyDocumentByID)
	mux.HandleFunc("/api/v1/business/financial-summary", businessHandler.FinancialSummary)
	mux.HandleFunc("/api/v1/business/company-balance", businessHandler.CompanyBalance)
	mux.HandleFunc("/api/v1/catalog/services", businessHandler.Services)
	mux.HandleFunc("/api/v1/catalog/services/", businessHandler.ServiceByID)
	mux.HandleFunc("/api/v1/production/recipes", businessHandler.Recipes)
	mux.HandleFunc("/api/v1/production/recipes/", businessHandler.RecipeByID)
	mux.HandleFunc("/api/v1/production/orders", businessHandler.ProductionOrders)
	mux.HandleFunc("/api/v1/production/orders/", businessHandler.ProductionOrderByID)
	mux.HandleFunc("/api/v1/payroll/users", businessHandler.PayrollUsers)
	mux.HandleFunc("/api/v1/payroll/me/statement", businessHandler.CurrentEmployeeStatement)
	mux.HandleFunc("/api/v1/payroll/employees", businessHandler.Employees)
	mux.HandleFunc("/api/v1/payroll/employees/", businessHandler.EmployeeByID)
	mux.HandleFunc("/api/v1/payroll/periods", businessHandler.PayrollPeriods)
	mux.HandleFunc("/api/v1/payroll/periods/", businessHandler.PayrollPeriodByID)
	mux.HandleFunc("/api/v1/payroll/recipe-rates/", businessHandler.RecipeRates)
	mux.HandleFunc("/api/v1/companies", businessHandler.Companies)
	mux.HandleFunc("/api/v1/companies/", businessHandler.CompanyByID)

	return withRecovery(withLogging(withCORS(mux, cfg.AllowedOrigins)))
}
