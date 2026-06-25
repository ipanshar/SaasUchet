package business

import (
	"database/sql"
	"encoding/json"
	"errors"
	"io"
	"log"
	"net/http"
	"path/filepath"
	"strings"

	"github.com/altyncloud/saas-uchet/backend/internal/auth"
	"github.com/altyncloud/saas-uchet/backend/internal/response"
)

type Authenticator interface {
	Authenticate(accessToken string) (auth.User, error)
}

type Handler struct {
	authenticator Authenticator
	store         Store
}

func NewHandler(authenticator Authenticator, store Store) Handler {
	return Handler{authenticator: authenticator, store: store}
}

func (h Handler) Overview(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		response.Error(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}

	user, ok := h.authorize(w, r)
	if !ok {
		return
	}

	membership, ok, err := h.resolveUserCompanyMembership(user, strings.TrimSpace(user.ActiveCompanyID))
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "internal server error")
		return
	}
	if !ok {
		response.Error(w, http.StatusForbidden, "forbidden")
		return
	}
	role := strings.TrimSpace(strings.ToLower(membership.Role))
	permissions := permissionsForRole(role)

	var clients []Client
	if hasPermission(role, permCRMRead) {
		clients, err = h.loadClients(user)
		if err != nil {
			log.Printf("business overview loadClients failed user=%s: %v", user.ID, err)
			response.Error(w, http.StatusInternalServerError, "internal server error")
			return
		}
	}

	var products []Product
	if hasPermission(role, permCatalogRead) || hasPermission(role, permWarehouseRead) {
		products, err = h.store.ListProducts(user)
		if err != nil {
			log.Printf("business overview ListProducts failed user=%s: %v", user.ID, err)
			response.Error(w, http.StatusInternalServerError, "internal server error")
			return
		}
	}

	var inventoryDocuments []InventoryDocumentSummary
	if hasPermission(role, permWarehouseRead) {
		inventoryDocuments, err = h.store.ListInventoryDocuments(user, "", "")
		if err != nil {
			log.Printf("business overview ListInventoryDocuments failed user=%s: %v", user.ID, err)
			response.Error(w, http.StatusInternalServerError, "internal server error")
			return
		}
	}

	var finance Finance
	var moneyDocuments []MoneyDocumentSummary
	if hasPermission(role, permFinanceRead) {
		finance, err = h.store.GetFinance(user)
		if err != nil {
			log.Printf("business overview GetFinance failed user=%s: %v", user.ID, err)
			response.Error(w, http.StatusInternalServerError, "internal server error")
			return
		}
		moneyDocuments, err = h.store.ListMoneyDocuments(user, "", "")
		if err != nil {
			log.Printf("business overview ListMoneyDocuments failed user=%s: %v", user.ID, err)
			response.Error(w, http.StatusInternalServerError, "internal server error")
			return
		}
	}

	var payrollPeriods []PayrollPeriod
	if hasPermission(role, permPayrollRead) {
		payrollPeriods, err = h.store.ListPayrollPeriods(user)
		if err != nil {
			log.Printf("business overview ListPayrollPeriods failed user=%s: %v", user.ID, err)
			response.Error(w, http.StatusInternalServerError, "internal server error")
			return
		}
	}

	companyName := membership.Name
	if strings.TrimSpace(companyName) == "" {
		companyName = h.resolveActiveCompanyName(user)
	}

	response.JSON(w, http.StatusOK, buildOverview(overviewBuildInput{
		User:               user,
		CompanyName:        companyName,
		ActiveRole:         role,
		Permissions:        permissions,
		Clients:            clients,
		Products:           products,
		Finance:            finance,
		InventoryDocuments: inventoryDocuments,
		MoneyDocuments:     moneyDocuments,
		PayrollPeriods:     payrollPeriods,
	}))
}

// resolveActiveCompanyName returns the name of the user's active company (or
// the default one). Empty string falls back to the legacy companies_json name.
func (h Handler) resolveActiveCompanyName(user auth.User) string {
	companies, err := h.store.ListUserCompanies(user)
	if err != nil || len(companies) == 0 {
		return ""
	}
	active := strings.TrimSpace(user.ActiveCompanyID)
	for _, company := range companies {
		if active != "" && company.ID == active {
			return company.Name
		}
	}
	for _, company := range companies {
		if company.IsDefault {
			return company.Name
		}
	}
	return companies[0].Name
}

func (h Handler) Clients(w http.ResponseWriter, r *http.Request) {
	user, ok := h.authorize(w, r)
	if !ok {
		return
	}
	permission := permCRMRead
	if r.Method != http.MethodGet {
		permission = permCRMWrite
	}
	if !h.requireActiveCompanyPermission(w, user, permission) {
		return
	}

	switch r.Method {
	case http.MethodGet:
		h.listClients(w, user)
	case http.MethodPost:
		h.createClient(w, r, user)
	default:
		response.Error(w, http.StatusMethodNotAllowed, "method not allowed")
	}
}

func (h Handler) ClientByID(w http.ResponseWriter, r *http.Request) {
	user, ok := h.authorize(w, r)
	if !ok {
		return
	}

	path := strings.TrimSpace(strings.TrimPrefix(r.URL.Path, "/api/v1/business/clients/"))
	parts := strings.Split(path, "/")
	clientID := strings.TrimSpace(parts[0])
	if clientID == "" {
		response.Error(w, http.StatusNotFound, "client not found")
		return
	}

	if len(parts) == 2 && parts[1] == "statement" {
		if r.Method != http.MethodGet {
			response.Error(w, http.StatusMethodNotAllowed, "method not allowed")
			return
		}
		if !h.requireActiveCompanyPermission(w, user, permCRMRead) {
			return
		}
		from := strings.TrimSpace(r.URL.Query().Get("from"))
		to := strings.TrimSpace(r.URL.Query().Get("to"))
		statement, err := h.store.CounterpartyStatement(user, clientID, from, to)
		if err != nil {
			if errors.Is(err, ErrValidation) {
				response.Error(w, http.StatusBadRequest, "invalid statement request")
				return
			}
			response.Error(w, http.StatusInternalServerError, "internal server error")
			return
		}
		response.JSON(w, http.StatusOK, statement)
		return
	}

	if len(parts) != 1 {
		response.Error(w, http.StatusNotFound, "client not found")
		return
	}
	if !h.requireActiveCompanyPermission(w, user, permCRMWrite) {
		return
	}

	switch r.Method {
	case http.MethodPut:
		h.updateClient(w, r, user, clientID)
	case http.MethodDelete:
		h.deleteClient(w, user, clientID)
	default:
		response.Error(w, http.StatusMethodNotAllowed, "method not allowed")
	}
}

func (h Handler) Products(w http.ResponseWriter, r *http.Request) {
	user, ok := h.authorize(w, r)
	if !ok {
		return
	}
	permission := permCatalogRead
	if r.Method != http.MethodGet {
		permission = permCatalogWrite
	}
	if !h.requireActiveCompanyPermission(w, user, permission) {
		return
	}

	switch r.Method {
	case http.MethodGet:
		products, err := h.store.ListProducts(user)
		if err != nil {
			response.Error(w, http.StatusInternalServerError, "internal server error")
			return
		}
		response.JSON(w, http.StatusOK, map[string]any{"products": products})
	case http.MethodPost:
		var input CreateProductInput
		if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
			response.Error(w, http.StatusBadRequest, "invalid request body")
			return
		}

		input = NormalizeProductInput(input)
		if err := ValidateProductInput(input); err != nil {
			response.Error(w, http.StatusBadRequest, err.Error())
			return
		}

		product, err := h.store.CreateProduct(user, input)
		if err != nil {
			response.Error(w, http.StatusInternalServerError, "internal server error")
			return
		}

		response.JSON(w, http.StatusCreated, product)
	default:
		response.Error(w, http.StatusMethodNotAllowed, "method not allowed")
	}
}

func (h Handler) Warehouses(w http.ResponseWriter, r *http.Request) {
	user, ok := h.authorize(w, r)
	if !ok {
		return
	}
	permission := permWarehouseRead
	if r.Method != http.MethodGet {
		permission = permWarehouseWrite
	}
	if !h.requireActiveCompanyPermission(w, user, permission) {
		return
	}

	switch r.Method {
	case http.MethodGet:
		warehouses, err := h.store.ListWarehouses(user)
		if err != nil {
			response.Error(w, http.StatusInternalServerError, "internal server error")
			return
		}
		response.JSON(w, http.StatusOK, map[string]any{"warehouses": warehouses})
	case http.MethodPost:
		var input CreateWarehouseInput
		if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
			response.Error(w, http.StatusBadRequest, "invalid request body")
			return
		}
		input = NormalizeWarehouseInput(input)
		if err := ValidateWarehouseInput(input); err != nil {
			response.Error(w, http.StatusBadRequest, err.Error())
			return
		}
		warehouse, err := h.store.CreateWarehouse(user, input)
		if err != nil {
			if errors.Is(err, ErrValidation) {
				response.Error(w, http.StatusBadRequest, err.Error())
				return
			}
			response.Error(w, http.StatusInternalServerError, "internal server error")
			return
		}
		response.JSON(w, http.StatusCreated, warehouse)
	default:
		response.Error(w, http.StatusMethodNotAllowed, "method not allowed")
	}
}

func (h Handler) ProductByID(w http.ResponseWriter, r *http.Request) {
	user, ok := h.authorize(w, r)
	if !ok {
		return
	}

	productID := strings.TrimSpace(strings.TrimPrefix(r.URL.Path, "/api/v1/business/products/"))
	if productID == "" || strings.Contains(productID, "/") {
		response.Error(w, http.StatusNotFound, "product not found")
		return
	}
	if !h.requireActiveCompanyPermission(w, user, permCatalogWrite) {
		return
	}

	switch r.Method {
	case http.MethodPut:
		var input CreateProductInput
		if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
			response.Error(w, http.StatusBadRequest, "invalid request body")
			return
		}

		input = NormalizeProductInput(input)
		if err := ValidateProductInput(input); err != nil {
			response.Error(w, http.StatusBadRequest, err.Error())
			return
		}

		product, err := h.store.UpdateProduct(user, productID, input)
		if err != nil {
			response.Error(w, http.StatusNotFound, "product not found")
			return
		}

		response.JSON(w, http.StatusOK, product)
	case http.MethodDelete:
		if err := h.store.DeleteProduct(user, productID); err != nil {
			response.Error(w, http.StatusNotFound, "product not found")
			return
		}

		w.WriteHeader(http.StatusNoContent)
	default:
		response.Error(w, http.StatusMethodNotAllowed, "method not allowed")
	}
}

func (h Handler) Accounts(w http.ResponseWriter, r *http.Request) {
	user, ok := h.authorize(w, r)
	if !ok {
		return
	}
	permission := permFinanceRead
	if r.Method != http.MethodGet {
		permission = permFinanceWrite
	}
	if !h.requireActiveCompanyPermission(w, user, permission) {
		return
	}

	switch r.Method {
	case http.MethodGet:
		finance, err := h.store.GetFinance(user)
		if err != nil {
			response.Error(w, http.StatusInternalServerError, "internal server error")
			return
		}
		response.JSON(w, http.StatusOK, map[string]any{
			"accounts": finance.Accounts,
			"summary": map[string]any{
				"total_balance": finance.TotalBalance,
				"income":        finance.Income,
				"expense":       finance.Expense,
			},
		})
	case http.MethodPost:
		var input CreateCashAccountInput
		if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
			response.Error(w, http.StatusBadRequest, "invalid request body")
			return
		}

		input = NormalizeCashAccountInput(input)
		if err := ValidateCashAccountInput(input); err != nil {
			response.Error(w, http.StatusBadRequest, err.Error())
			return
		}

		account, err := h.store.CreateCashAccount(user, input)
		if err != nil {
			response.Error(w, http.StatusInternalServerError, "internal server error")
			return
		}

		response.JSON(w, http.StatusCreated, account)
	default:
		response.Error(w, http.StatusMethodNotAllowed, "method not allowed")
	}
}

func (h Handler) MoneyOperations(w http.ResponseWriter, r *http.Request) {
	user, ok := h.authorize(w, r)
	if !ok {
		return
	}
	if !h.requireActiveCompanyPermission(w, user, permFinanceWrite) {
		return
	}

	if r.Method != http.MethodPost {
		response.Error(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}

	var input CreateMoneyOperationInput
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		response.Error(w, http.StatusBadRequest, "invalid request body")
		return
	}

	input = NormalizeMoneyOperationInput(input)
	if err := ValidateMoneyOperationInput(input); err != nil {
		response.Error(w, http.StatusBadRequest, err.Error())
		return
	}

	if err := h.store.CreateMoneyOperation(user, input); err != nil {
		if errors.Is(err, ErrValidation) {
			response.Error(w, http.StatusBadRequest, err.Error())
			return
		}
		response.Error(w, http.StatusInternalServerError, "internal server error")
		return
	}

	response.JSON(w, http.StatusCreated, map[string]any{
		"status": "ok",
	})
}

func (h Handler) InventoryDocuments(w http.ResponseWriter, r *http.Request) {
	user, ok := h.authorize(w, r)
	if !ok {
		return
	}

	switch r.Method {
	case http.MethodGet:
		if !h.requireActiveCompanyPermission(w, user, permWarehouseRead) {
			return
		}
		documentType := strings.TrimSpace(r.URL.Query().Get("type"))
		search := strings.TrimSpace(r.URL.Query().Get("search"))
		documents, err := h.store.ListInventoryDocuments(user, documentType, search)
		if err != nil {
			response.Error(w, http.StatusInternalServerError, "internal server error")
			return
		}

		response.JSON(w, http.StatusOK, map[string]any{
			"documents": documents,
		})
	case http.MethodPost:
		var input CreateInventoryDocumentInput
		if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
			response.Error(w, http.StatusBadRequest, "invalid request body")
			return
		}

		input = NormalizeInventoryDocumentInput(input)
		if !h.requireInventoryDocumentWrite(w, user, input.DocumentType) {
			return
		}
		if err := ValidateInventoryDocumentInput(input); err != nil {
			response.Error(w, http.StatusBadRequest, err.Error())
			return
		}

		document, err := h.store.CreateInventoryDocument(user, input)
		if err != nil {
			if errors.Is(err, ErrValidation) {
				response.Error(w, http.StatusBadRequest, err.Error())
				return
			}
			response.Error(w, http.StatusInternalServerError, "internal server error")
			return
		}

		response.JSON(w, http.StatusCreated, document)
	default:
		response.Error(w, http.StatusMethodNotAllowed, "method not allowed")
	}
}

func (h Handler) InventoryDocumentByID(w http.ResponseWriter, r *http.Request) {
	user, ok := h.authorize(w, r)
	if !ok {
		return
	}

	path := strings.TrimSpace(strings.TrimPrefix(r.URL.Path, "/api/v1/business/inventory-documents/"))
	if path == "" {
		response.Error(w, http.StatusNotFound, "document not found")
		return
	}

	parts := strings.Split(path, "/")
	documentID := strings.TrimSpace(parts[0])
	action := ""
	if len(parts) > 1 {
		action = strings.TrimSpace(parts[1])
	}
	if documentID == "" || len(parts) > 2 {
		response.Error(w, http.StatusNotFound, "document not found")
		return
	}

	if action == "post" {
		if r.Method != http.MethodPost {
			response.Error(w, http.StatusMethodNotAllowed, "method not allowed")
			return
		}
		existing, err := h.store.GetInventoryDocument(user, documentID)
		if err != nil {
			response.Error(w, http.StatusNotFound, "document not found")
			return
		}
		if !h.requireInventoryDocumentWrite(w, user, existing.Summary.DocumentType) {
			return
		}
		document, err := h.store.PostInventoryDocument(user, documentID)
		if err != nil {
			h.writeInventoryDocumentMutationError(w, err)
			return
		}
		response.JSON(w, http.StatusOK, document)
		return
	}
	if action != "" {
		response.Error(w, http.StatusNotFound, "document action not found")
		return
	}

	switch r.Method {
	case http.MethodGet:
		if !h.requireActiveCompanyPermission(w, user, permWarehouseRead) {
			return
		}
		document, err := h.store.GetInventoryDocument(user, documentID)
		if err != nil {
			response.Error(w, http.StatusNotFound, "document not found")
			return
		}
		response.JSON(w, http.StatusOK, document)
	case http.MethodPut:
		var input CreateInventoryDocumentInput
		if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
			response.Error(w, http.StatusBadRequest, "invalid request body")
			return
		}
		input = NormalizeInventoryDocumentInput(input)
		if !h.requireInventoryDocumentWrite(w, user, input.DocumentType) {
			return
		}
		if err := ValidateInventoryDocumentInput(input); err != nil {
			response.Error(w, http.StatusBadRequest, err.Error())
			return
		}
		document, err := h.store.UpdateInventoryDocument(user, documentID, input)
		if err != nil {
			h.writeInventoryDocumentMutationError(w, err)
			return
		}
		response.JSON(w, http.StatusOK, document)
	case http.MethodDelete:
		existing, err := h.store.GetInventoryDocument(user, documentID)
		if err != nil {
			response.Error(w, http.StatusNotFound, "document not found")
			return
		}
		if !h.requireInventoryDocumentWrite(w, user, existing.Summary.DocumentType) {
			return
		}
		if err := h.store.DeleteInventoryDocument(user, documentID); err != nil {
			h.writeInventoryDocumentMutationError(w, err)
			return
		}
		w.WriteHeader(http.StatusNoContent)
	default:
		response.Error(w, http.StatusMethodNotAllowed, "method not allowed")
	}
}

func (h Handler) writeInventoryDocumentMutationError(w http.ResponseWriter, err error) {
	if errors.Is(err, ErrValidation) {
		response.Error(w, http.StatusBadRequest, err.Error())
		return
	}
	if errors.Is(err, sql.ErrNoRows) {
		response.Error(w, http.StatusNotFound, "document not found")
		return
	}
	response.Error(w, http.StatusInternalServerError, "internal server error")
}

func (h Handler) WarehouseByID(w http.ResponseWriter, r *http.Request) {
	user, ok := h.authorize(w, r)
	if !ok {
		return
	}

	path := strings.TrimSpace(strings.TrimPrefix(r.URL.Path, "/api/v1/business/warehouses/"))
	parts := strings.Split(path, "/")
	if len(parts) != 2 || strings.TrimSpace(parts[0]) == "" {
		response.Error(w, http.StatusNotFound, "warehouse not found")
		return
	}

	warehouseID := strings.TrimSpace(parts[0])
	action := strings.TrimSpace(parts[1])
	search := strings.TrimSpace(r.URL.Query().Get("search"))

	if r.Method != http.MethodGet {
		response.Error(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	if !h.requireActiveCompanyPermission(w, user, permWarehouseRead) {
		return
	}

	switch action {
	case "stock":
		items, err := h.store.ListWarehouseStock(user, warehouseID, search)
		if err != nil {
			if errors.Is(err, ErrValidation) {
				response.Error(w, http.StatusNotFound, "warehouse not found")
				return
			}
			response.Error(w, http.StatusInternalServerError, "internal server error")
			return
		}
		response.JSON(w, http.StatusOK, map[string]any{"items": items})
	case "movements":
		movements, err := h.store.ListWarehouseMovements(user, warehouseID, search)
		if err != nil {
			if errors.Is(err, ErrValidation) {
				response.Error(w, http.StatusNotFound, "warehouse not found")
				return
			}
			response.Error(w, http.StatusInternalServerError, "internal server error")
			return
		}
		response.JSON(w, http.StatusOK, map[string]any{"movements": movements})
	case "turnover":
		from := strings.TrimSpace(r.URL.Query().Get("from"))
		to := strings.TrimSpace(r.URL.Query().Get("to"))
		items, err := h.store.ListWarehouseTurnover(user, warehouseID, from, to)
		if err != nil {
			if errors.Is(err, ErrValidation) {
				response.Error(w, http.StatusBadRequest, "invalid period")
				return
			}
			response.Error(w, http.StatusInternalServerError, "internal server error")
			return
		}
		response.JSON(w, http.StatusOK, map[string]any{"items": items})
	default:
		response.Error(w, http.StatusNotFound, "warehouse section not found")
	}
}

func (h Handler) FinancialSummary(w http.ResponseWriter, r *http.Request) {
	user, ok := h.authorize(w, r)
	if !ok {
		return
	}

	if r.Method != http.MethodGet {
		response.Error(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	if !h.requireActiveCompanyPermission(w, user, permFinanceRead) {
		return
	}

	from := strings.TrimSpace(r.URL.Query().Get("from"))
	to := strings.TrimSpace(r.URL.Query().Get("to"))
	summary, err := h.store.FinancialSummary(user, from, to)
	if err != nil {
		if errors.Is(err, ErrValidation) {
			response.Error(w, http.StatusBadRequest, "invalid period")
			return
		}
		response.Error(w, http.StatusInternalServerError, "internal server error")
		return
	}
	response.JSON(w, http.StatusOK, summary)
}

func (h Handler) MoneyDocuments(w http.ResponseWriter, r *http.Request) {
	user, ok := h.authorize(w, r)
	if !ok {
		return
	}

	if r.Method != http.MethodGet {
		response.Error(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	if !h.requireActiveCompanyPermission(w, user, permFinanceRead) {
		return
	}

	documentType := strings.TrimSpace(r.URL.Query().Get("type"))
	search := strings.TrimSpace(r.URL.Query().Get("search"))
	documents, err := h.store.ListMoneyDocuments(user, documentType, search)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "internal server error")
		return
	}

	response.JSON(w, http.StatusOK, map[string]any{
		"documents": documents,
	})
}

func (h Handler) MoneyDocumentByID(w http.ResponseWriter, r *http.Request) {
	user, ok := h.authorize(w, r)
	if !ok {
		return
	}

	path := strings.TrimSpace(strings.TrimPrefix(r.URL.Path, "/api/v1/business/money-documents/"))
	if path == "" {
		response.Error(w, http.StatusNotFound, "document not found")
		return
	}

	if strings.HasSuffix(path, "/settle") {
		if !h.requireActiveCompanyPermission(w, user, permFinanceWrite) {
			return
		}
		if r.Method != http.MethodPost {
			response.Error(w, http.StatusMethodNotAllowed, "method not allowed")
			return
		}

		documentID := strings.TrimSpace(strings.TrimSuffix(path, "/settle"))
		if documentID == "" || strings.Contains(documentID, "/") {
			response.Error(w, http.StatusNotFound, "document not found")
			return
		}

		var input SettleMoneyDocumentInput
		if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
			response.Error(w, http.StatusBadRequest, "invalid request body")
			return
		}

		input = NormalizeSettleMoneyDocumentInput(input)
		if err := ValidateSettleMoneyDocumentInput(input); err != nil {
			response.Error(w, http.StatusBadRequest, err.Error())
			return
		}

		if err := h.store.SettleMoneyDocument(user, documentID, input); err != nil {
			if errors.Is(err, ErrValidation) {
				response.Error(w, http.StatusBadRequest, err.Error())
				return
			}
			response.Error(w, http.StatusInternalServerError, "internal server error")
			return
		}

		response.JSON(w, http.StatusCreated, map[string]any{"status": "ok"})
		return
	}

	if r.Method != http.MethodGet {
		response.Error(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	if !h.requireActiveCompanyPermission(w, user, permFinanceRead) {
		return
	}

	documentID := strings.TrimSpace(path)
	if documentID == "" || strings.Contains(documentID, "/") {
		response.Error(w, http.StatusNotFound, "document not found")
		return
	}

	document, err := h.store.GetMoneyDocument(user, documentID)
	if err != nil {
		response.Error(w, http.StatusNotFound, "document not found")
		return
	}
	response.JSON(w, http.StatusOK, document)
}

func (h Handler) listClients(w http.ResponseWriter, user auth.User) {
	clients, err := h.loadClients(user)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "internal server error")
		return
	}

	response.JSON(w, http.StatusOK, map[string]any{
		"clients": clients,
	})
}

func (h Handler) createClient(w http.ResponseWriter, r *http.Request, user auth.User) {
	var input CreateClientInput
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		response.Error(w, http.StatusBadRequest, "invalid request body")
		return
	}

	input = NormalizeClientInput(input)
	if err := ValidateClientInput(input); err != nil {
		response.Error(w, http.StatusBadRequest, err.Error())
		return
	}

	clients, err := h.loadClients(user)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "internal server error")
		return
	}

	client := NewClientFromInput(input)
	clients = append([]Client{client}, clients...)

	if err := h.store.SaveClients(user, clients); err != nil {
		response.Error(w, http.StatusInternalServerError, "internal server error")
		return
	}

	response.JSON(w, http.StatusCreated, client)
}

func (h Handler) updateClient(w http.ResponseWriter, r *http.Request, user auth.User, clientID string) {
	var input CreateClientInput
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		response.Error(w, http.StatusBadRequest, "invalid request body")
		return
	}

	input = NormalizeClientInput(input)
	if err := ValidateClientInput(input); err != nil {
		response.Error(w, http.StatusBadRequest, err.Error())
		return
	}

	clients, err := h.loadClients(user)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "internal server error")
		return
	}

	index := indexOfClient(clients, clientID)
	if index < 0 {
		response.Error(w, http.StatusNotFound, "client not found")
		return
	}

	clients[index] = UpdatedClientFromInput(clients[index], input)
	if err := h.store.SaveClients(user, clients); err != nil {
		response.Error(w, http.StatusInternalServerError, "internal server error")
		return
	}

	response.JSON(w, http.StatusOK, clients[index])
}

func (h Handler) deleteClient(w http.ResponseWriter, user auth.User, clientID string) {
	clients, err := h.loadClients(user)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "internal server error")
		return
	}

	index := indexOfClient(clients, clientID)
	if index < 0 {
		response.Error(w, http.StatusNotFound, "client not found")
		return
	}

	clients = append(clients[:index], clients[index+1:]...)
	if err := h.store.SaveClients(user, clients); err != nil {
		response.Error(w, http.StatusInternalServerError, "internal server error")
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

func (h Handler) loadClients(user auth.User) ([]Client, error) {
	return h.store.ListClients(user)
}

func indexOfClient(clients []Client, clientID string) int {
	for index, client := range clients {
		if client.ID == clientID {
			return index
		}
	}

	return -1
}

func (h Handler) Services(w http.ResponseWriter, r *http.Request) {
	user, ok := h.authorize(w, r)
	if !ok {
		return
	}
	permission := permCatalogRead
	if r.Method != http.MethodGet {
		permission = permCatalogWrite
	}
	if !h.requireActiveCompanyPermission(w, user, permission) {
		return
	}

	switch r.Method {
	case http.MethodGet:
		services, err := h.store.ListServices(user)
		if err != nil {
			response.Error(w, http.StatusInternalServerError, "internal server error")
			return
		}
		response.JSON(w, http.StatusOK, map[string]any{"services": services})
	case http.MethodPost:
		var input CreateServiceInput
		if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
			response.Error(w, http.StatusBadRequest, "invalid request body")
			return
		}
		input = NormalizeServiceInput(input)
		if err := ValidateServiceInput(input); err != nil {
			response.Error(w, http.StatusBadRequest, err.Error())
			return
		}
		svc, err := h.store.CreateService(user, input)
		if err != nil {
			response.Error(w, http.StatusInternalServerError, "internal server error")
			return
		}
		response.JSON(w, http.StatusCreated, svc)
	default:
		response.Error(w, http.StatusMethodNotAllowed, "method not allowed")
	}
}

func (h Handler) ServiceByID(w http.ResponseWriter, r *http.Request) {
	user, ok := h.authorize(w, r)
	if !ok {
		return
	}

	serviceID := strings.TrimSpace(strings.TrimPrefix(r.URL.Path, "/api/v1/catalog/services/"))
	if serviceID == "" || strings.Contains(serviceID, "/") {
		response.Error(w, http.StatusNotFound, "service not found")
		return
	}
	if !h.requireActiveCompanyPermission(w, user, permCatalogWrite) {
		return
	}

	switch r.Method {
	case http.MethodPut:
		var input CreateServiceInput
		if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
			response.Error(w, http.StatusBadRequest, "invalid request body")
			return
		}
		input = NormalizeServiceInput(input)
		if err := ValidateServiceInput(input); err != nil {
			response.Error(w, http.StatusBadRequest, err.Error())
			return
		}
		svc, err := h.store.UpdateService(user, serviceID, input)
		if err != nil {
			response.Error(w, http.StatusNotFound, "service not found")
			return
		}
		response.JSON(w, http.StatusOK, svc)
	case http.MethodDelete:
		if err := h.store.DeleteService(user, serviceID); err != nil {
			response.Error(w, http.StatusNotFound, "service not found")
			return
		}
		w.WriteHeader(http.StatusNoContent)
	default:
		response.Error(w, http.StatusMethodNotAllowed, "method not allowed")
	}
}

func (h Handler) Recipes(w http.ResponseWriter, r *http.Request) {
	user, ok := h.authorize(w, r)
	if !ok {
		return
	}
	permission := permProductionRead
	if r.Method != http.MethodGet {
		permission = permProductionWrite
	}
	if !h.requireActiveCompanyPermission(w, user, permission) {
		return
	}

	switch r.Method {
	case http.MethodGet:
		recipes, err := h.store.ListRecipes(user)
		if err != nil {
			response.Error(w, http.StatusInternalServerError, "internal server error")
			return
		}
		response.JSON(w, http.StatusOK, map[string]any{"recipes": recipes})
	case http.MethodPost:
		var input CreateRecipeInput
		if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
			response.Error(w, http.StatusBadRequest, "invalid request body")
			return
		}
		input = NormalizeRecipeInput(input)
		if err := ValidateRecipeInput(input); err != nil {
			response.Error(w, http.StatusBadRequest, err.Error())
			return
		}
		recipe, err := h.store.CreateRecipe(user, input)
		if err != nil {
			response.Error(w, http.StatusInternalServerError, "internal server error")
			return
		}
		response.JSON(w, http.StatusCreated, recipe)
	default:
		response.Error(w, http.StatusMethodNotAllowed, "method not allowed")
	}
}

func (h Handler) RecipeByID(w http.ResponseWriter, r *http.Request) {
	user, ok := h.authorize(w, r)
	if !ok {
		return
	}

	recipeID := strings.TrimSpace(strings.TrimPrefix(r.URL.Path, "/api/v1/production/recipes/"))
	if recipeID == "" || strings.Contains(recipeID, "/") {
		response.Error(w, http.StatusNotFound, "recipe not found")
		return
	}
	if !h.requireActiveCompanyPermission(w, user, permProductionWrite) {
		return
	}

	switch r.Method {
	case http.MethodPut:
		var input CreateRecipeInput
		if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
			response.Error(w, http.StatusBadRequest, "invalid request body")
			return
		}
		input = NormalizeRecipeInput(input)
		if err := ValidateRecipeInput(input); err != nil {
			response.Error(w, http.StatusBadRequest, err.Error())
			return
		}
		recipe, err := h.store.UpdateRecipe(user, recipeID, input)
		if err != nil {
			response.Error(w, http.StatusNotFound, "recipe not found")
			return
		}
		response.JSON(w, http.StatusOK, recipe)
	case http.MethodDelete:
		if err := h.store.DeleteRecipe(user, recipeID); err != nil {
			response.Error(w, http.StatusNotFound, "recipe not found")
			return
		}
		w.WriteHeader(http.StatusNoContent)
	default:
		response.Error(w, http.StatusMethodNotAllowed, "method not allowed")
	}
}

func (h Handler) ProductionOrders(w http.ResponseWriter, r *http.Request) {
	user, ok := h.authorize(w, r)
	if !ok {
		return
	}
	permission := permProductionRead
	if r.Method != http.MethodGet {
		permission = permProductionWrite
	}
	if !h.requireActiveCompanyPermission(w, user, permission) {
		return
	}

	switch r.Method {
	case http.MethodGet:
		orders, err := h.store.ListProductionOrders(user)
		if err != nil {
			response.Error(w, http.StatusInternalServerError, "internal server error")
			return
		}
		response.JSON(w, http.StatusOK, map[string]any{"orders": orders})
	case http.MethodPost:
		var input CreateProductionOrderInput
		if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
			response.Error(w, http.StatusBadRequest, "invalid request body")
			return
		}
		input = NormalizeProductionOrderInput(input)
		if err := ValidateProductionOrderInput(input); err != nil {
			response.Error(w, http.StatusBadRequest, err.Error())
			return
		}
		order, err := h.store.CreateProductionOrder(user, input)
		if err != nil {
			response.Error(w, http.StatusInternalServerError, "internal server error")
			return
		}
		response.JSON(w, http.StatusCreated, order)
	default:
		response.Error(w, http.StatusMethodNotAllowed, "method not allowed")
	}
}

func (h Handler) ProductionOrderByID(w http.ResponseWriter, r *http.Request) {
	user, ok := h.authorize(w, r)
	if !ok {
		return
	}

	orderID := strings.TrimSpace(strings.TrimPrefix(r.URL.Path, "/api/v1/production/orders/"))
	if orderID == "" || strings.Contains(orderID, "/") {
		response.Error(w, http.StatusNotFound, "order not found")
		return
	}
	if !h.requireActiveCompanyPermission(w, user, permProductionWrite) {
		return
	}

	if r.Method != http.MethodPatch {
		response.Error(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}

	var input UpdateProductionOrderStatusInput
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		response.Error(w, http.StatusBadRequest, "invalid request body")
		return
	}
	order, err := h.store.UpdateProductionOrderStatus(user, orderID, input)
	if err != nil {
		if errors.Is(err, ErrValidation) {
			response.Error(w, http.StatusBadRequest, err.Error())
			return
		}
		response.Error(w, http.StatusInternalServerError, "internal server error")
		return
	}
	response.JSON(w, http.StatusOK, order)
}

func (h Handler) Companies(w http.ResponseWriter, r *http.Request) {
	user, ok := h.authorize(w, r)
	if !ok {
		return
	}

	switch r.Method {
	case http.MethodGet:
		companies, err := h.store.ListUserCompanies(user)
		if err != nil {
			response.Error(w, http.StatusInternalServerError, "internal server error")
			return
		}
		response.JSON(w, http.StatusOK, map[string]any{"companies": companies})
	case http.MethodPost:
		var input CreateCompanyInput
		if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
			response.Error(w, http.StatusBadRequest, "invalid request body")
			return
		}
		company, err := h.store.CreateCompany(user, input)
		if err != nil {
			if errors.Is(err, ErrValidation) {
				response.Error(w, http.StatusBadRequest, err.Error())
				return
			}
			response.Error(w, http.StatusInternalServerError, "internal server error")
			return
		}
		response.JSON(w, http.StatusCreated, company)
	default:
		response.Error(w, http.StatusMethodNotAllowed, "method not allowed")
	}
}

func (h Handler) CompanyByID(w http.ResponseWriter, r *http.Request) {
	user, ok := h.authorize(w, r)
	if !ok {
		return
	}

	rest := strings.TrimSpace(strings.TrimPrefix(r.URL.Path, "/api/v1/companies/"))
	if rest == "" {
		response.Error(w, http.StatusNotFound, "company not found")
		return
	}

	parts := strings.Split(rest, "/")
	companyID := parts[0]
	action := ""
	memberID := ""
	if len(parts) > 1 {
		action = parts[1]
	}
	if len(parts) > 2 {
		memberID = parts[2]
	}
	if companyID == "" {
		response.Error(w, http.StatusNotFound, "company not found")
		return
	}

	switch action {
	case "":
		permission := permCompanySettingsRead
		if r.Method != http.MethodGet {
			permission = permCompanySettingsWrite
		}
		if !h.requireCompanyPermission(w, user, companyID, permission) {
			return
		}
		switch r.Method {
		case http.MethodGet:
			detail, err := h.store.GetCompany(user, companyID)
			if err != nil {
				if errors.Is(err, ErrValidation) {
					response.Error(w, http.StatusBadRequest, err.Error())
					return
				}
				response.Error(w, http.StatusInternalServerError, "internal server error")
				return
			}
			response.JSON(w, http.StatusOK, detail)
		case http.MethodPut:
			var input UpdateCompanyInput
			if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
				response.Error(w, http.StatusBadRequest, "invalid request body")
				return
			}
			detail, err := h.store.UpdateCompany(user, companyID, input)
			if err != nil {
				if errors.Is(err, ErrValidation) {
					response.Error(w, http.StatusBadRequest, err.Error())
					return
				}
				response.Error(w, http.StatusInternalServerError, "internal server error")
				return
			}
			response.JSON(w, http.StatusOK, detail)
		default:
			response.Error(w, http.StatusMethodNotAllowed, "method not allowed")
		}
	case "logo":
		if !h.requireCompanyMembership(w, user, companyID) {
			return
		}
		switch r.Method {
		case http.MethodGet:
			logoPNG, err := h.store.GetCompanyLogo(user, companyID)
			if err != nil {
				if errors.Is(err, ErrValidation) {
					response.Error(w, http.StatusNotFound, "logo not found")
					return
				}
				response.Error(w, http.StatusInternalServerError, "internal server error")
				return
			}
			w.Header().Set("Content-Type", "image/png")
			w.Header().Set("Cache-Control", "private, max-age=300")
			_, _ = w.Write(logoPNG)
		case http.MethodPut:
			if !h.requireCompanyPermission(w, user, companyID, permCompanySettingsWrite) {
				return
			}
			r.Body = http.MaxBytesReader(w, r.Body, maxCompanyLogoBytes+(256<<10))
			if err := r.ParseMultipartForm(maxCompanyLogoBytes + (256 << 10)); err != nil {
				response.Error(w, http.StatusBadRequest, "не удалось прочитать файл логотипа")
				return
			}
			file, fileHeader, err := r.FormFile("file")
			if err != nil {
				response.Error(w, http.StatusBadRequest, "файл логотипа обязателен")
				return
			}
			defer file.Close()
			if fileHeader.Size > maxCompanyLogoBytes {
				response.Error(w, http.StatusBadRequest, "логотип должен быть не больше 2 МБ")
				return
			}
			rawLogo, err := io.ReadAll(file)
			if err != nil {
				response.Error(w, http.StatusBadRequest, "не удалось прочитать файл логотипа")
				return
			}
			logoPNG, err := normalizeCompanyLogo(filepath.Base(fileHeader.Filename), rawLogo)
			if err != nil {
				response.Error(w, http.StatusBadRequest, err.Error())
				return
			}
			detail, err := h.store.UpdateCompanyLogo(user, companyID, logoPNG)
			if err != nil {
				if errors.Is(err, ErrValidation) {
					response.Error(w, http.StatusBadRequest, err.Error())
					return
				}
				response.Error(w, http.StatusInternalServerError, "internal server error")
				return
			}
			response.JSON(w, http.StatusOK, detail)
		default:
			response.Error(w, http.StatusMethodNotAllowed, "method not allowed")
		}
	case "members":
		switch r.Method {
		case http.MethodGet:
			if memberID != "" {
				response.Error(w, http.StatusNotFound, "not found")
				return
			}
			if !h.requireCompanyPermission(w, user, companyID, permCompanyMembersRead) {
				return
			}
			members, err := h.store.ListCompanyMembers(user, companyID)
			if err != nil {
				if errors.Is(err, ErrValidation) {
					response.Error(w, http.StatusBadRequest, err.Error())
					return
				}
				response.Error(w, http.StatusInternalServerError, "internal server error")
				return
			}
			response.JSON(w, http.StatusOK, map[string]any{"members": members})
		case http.MethodPost:
			if memberID != "" {
				response.Error(w, http.StatusNotFound, "not found")
				return
			}
			if !h.requireCompanyPermission(w, user, companyID, permCompanyMembersWrite) {
				return
			}
			var input AddCompanyMemberInput
			if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
				response.Error(w, http.StatusBadRequest, "invalid request body")
				return
			}
			member, err := h.store.AddCompanyMember(user, companyID, input)
			if err != nil {
				if errors.Is(err, ErrValidation) {
					response.Error(w, http.StatusBadRequest, err.Error())
					return
				}
				response.Error(w, http.StatusInternalServerError, "internal server error")
				return
			}
			response.JSON(w, http.StatusCreated, member)
		case http.MethodPut:
			if memberID == "" {
				response.Error(w, http.StatusNotFound, "not found")
				return
			}
			if !h.requireCompanyPermission(w, user, companyID, permCompanyMembersWrite) {
				return
			}
			var input UpdateCompanyMemberRoleInput
			if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
				response.Error(w, http.StatusBadRequest, "invalid request body")
				return
			}
			member, err := h.store.UpdateCompanyMemberRole(user, companyID, memberID, input)
			if err != nil {
				if errors.Is(err, ErrValidation) {
					response.Error(w, http.StatusBadRequest, err.Error())
					return
				}
				response.Error(w, http.StatusInternalServerError, "internal server error")
				return
			}
			response.JSON(w, http.StatusOK, member)
		case http.MethodDelete:
			if memberID == "" {
				response.Error(w, http.StatusNotFound, "not found")
				return
			}
			if !h.requireCompanyPermission(w, user, companyID, permCompanyMembersWrite) {
				return
			}
			if err := h.store.RemoveCompanyMember(user, companyID, memberID); err != nil {
				if errors.Is(err, ErrValidation) {
					response.Error(w, http.StatusBadRequest, err.Error())
					return
				}
				response.Error(w, http.StatusInternalServerError, "internal server error")
				return
			}
			w.WriteHeader(http.StatusNoContent)
		default:
			response.Error(w, http.StatusMethodNotAllowed, "method not allowed")
		}
	case "default":
		if !h.requireCompanyMembership(w, user, companyID) {
			return
		}
		if r.Method != http.MethodPut {
			response.Error(w, http.StatusMethodNotAllowed, "method not allowed")
			return
		}
		if err := h.store.SetDefaultCompany(user, companyID); err != nil {
			if errors.Is(err, ErrValidation) {
				response.Error(w, http.StatusBadRequest, err.Error())
				return
			}
			response.Error(w, http.StatusInternalServerError, "internal server error")
			return
		}
		response.JSON(w, http.StatusOK, map[string]any{"status": "ok"})
	default:
		response.Error(w, http.StatusNotFound, "not found")
	}
}

func (h Handler) requireActiveCompanyPermission(w http.ResponseWriter, user auth.User, permissions ...string) bool {
	membership, ok, err := h.resolveUserCompanyMembership(user, strings.TrimSpace(user.ActiveCompanyID))
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "internal server error")
		return false
	}
	if !ok {
		response.Error(w, http.StatusForbidden, "forbidden")
		return false
	}
	if len(permissions) == 0 || membership.Role == "owner" || membership.Role == "admin" {
		return true
	}
	for _, permission := range permissions {
		if hasPermission(membership.Role, permission) {
			return true
		}
	}
	response.Error(w, http.StatusForbidden, "forbidden")
	return false
}

// requireInventoryDocumentWrite checks that the active user may write an
// inventory document of the given type. It lets the sales role manage only
// sale_issue documents while warehouse/owner/admin manage everything.
func (h Handler) requireInventoryDocumentWrite(w http.ResponseWriter, user auth.User, documentType string) bool {
	membership, ok, err := h.resolveUserCompanyMembership(user, strings.TrimSpace(user.ActiveCompanyID))
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "internal server error")
		return false
	}
	if !ok {
		response.Error(w, http.StatusForbidden, "forbidden")
		return false
	}
	if canWriteInventoryDocument(membership.Role, documentType) {
		return true
	}
	response.Error(w, http.StatusForbidden, "forbidden")
	return false
}

func (h Handler) requireCompanyPermission(w http.ResponseWriter, user auth.User, companyID string, permission string) bool {
	membership, ok, err := h.resolveUserCompanyMembership(user, companyID)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "internal server error")
		return false
	}
	if !ok || !hasPermission(membership.Role, permission) {
		response.Error(w, http.StatusForbidden, "forbidden")
		return false
	}
	return true
}

func (h Handler) requireCompanyMembership(w http.ResponseWriter, user auth.User, companyID string) bool {
	_, ok, err := h.resolveUserCompanyMembership(user, companyID)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "internal server error")
		return false
	}
	if !ok {
		response.Error(w, http.StatusForbidden, "forbidden")
		return false
	}
	return true
}

func (h Handler) resolveUserCompanyMembership(user auth.User, companyID string) (CompanyMembership, bool, error) {
	companies, err := h.store.ListUserCompanies(user)
	if err != nil {
		return CompanyMembership{}, false, err
	}
	if len(companies) == 0 {
		return CompanyMembership{}, false, nil
	}
	targetID := strings.TrimSpace(companyID)
	if targetID != "" {
		for _, company := range companies {
			if company.ID == targetID {
				return company, true, nil
			}
		}
		return CompanyMembership{}, false, nil
	}
	for _, company := range companies {
		if company.IsDefault {
			return company, true, nil
		}
	}
	return companies[0], true, nil
}

// authorize resolves the authenticated user and the active company (from the
// X-Company-Id header). On failure it writes the appropriate HTTP error and
// returns ok=false so the caller can simply return.
func (h Handler) authorize(w http.ResponseWriter, r *http.Request) (auth.User, bool) {
	accessToken, err := extractBearerToken(r.Header.Get("Authorization"))
	if err != nil {
		response.Error(w, http.StatusUnauthorized, err.Error())
		return auth.User{}, false
	}

	user, err := h.authenticator.Authenticate(accessToken)
	if err != nil {
		if errors.Is(err, auth.ErrUnauthorized) {
			response.Error(w, http.StatusUnauthorized, err.Error())
		} else {
			response.Error(w, http.StatusInternalServerError, "internal server error")
		}
		return auth.User{}, false
	}

	user.ActiveCompanyID = strings.TrimSpace(r.Header.Get("X-Company-Id"))
	return user, true
}

func extractBearerToken(headerValue string) (string, error) {
	if strings.TrimSpace(headerValue) == "" {
		return "", errors.New("authorization header is required")
	}

	parts := strings.SplitN(headerValue, " ", 2)
	if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") || strings.TrimSpace(parts[1]) == "" {
		return "", errors.New("authorization header must use Bearer token")
	}

	return strings.TrimSpace(parts[1]), nil
}
