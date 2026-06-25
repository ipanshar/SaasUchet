package business

import (
	"fmt"
	"strings"
	"sync"
	"time"

	"github.com/altyncloud/saas-uchet/backend/internal/auth"
)

type Store interface {
	ListClients(user auth.User) ([]Client, error)
	SaveClients(user auth.User, clients []Client) error
	ListWarehouses(user auth.User) ([]Warehouse, error)
	CreateWarehouse(user auth.User, input CreateWarehouseInput) (Warehouse, error)
	ListWarehouseStock(user auth.User, warehouseID string, search string) ([]WarehouseStockItem, error)
	ListWarehouseMovements(user auth.User, warehouseID string, search string) ([]WarehouseMovement, error)
	ListWarehouseTurnover(user auth.User, warehouseID string, from string, to string) ([]WarehouseTurnoverItem, error)
	FinancialSummary(user auth.User, from string, to string) (FinancialSummary, error)
	CounterpartyStatement(user auth.User, clientID string, from string, to string) (CounterpartyStatement, error)
	ListProducts(user auth.User) ([]Product, error)
	CreateProduct(user auth.User, input CreateProductInput) (Product, error)
	UpdateProduct(user auth.User, productID string, input CreateProductInput) (Product, error)
	DeleteProduct(user auth.User, productID string) error
	CreateInventoryDocument(user auth.User, input CreateInventoryDocumentInput) (InventoryDocumentDetail, error)
	ListInventoryDocuments(user auth.User, documentType string, search string) ([]InventoryDocumentSummary, error)
	GetInventoryDocument(user auth.User, documentID string) (InventoryDocumentDetail, error)
	UpdateInventoryDocument(user auth.User, documentID string, input CreateInventoryDocumentInput) (InventoryDocumentDetail, error)
	PostInventoryDocument(user auth.User, documentID string) (InventoryDocumentDetail, error)
	DeleteInventoryDocument(user auth.User, documentID string) error
	GetFinance(user auth.User) (Finance, error)
	CreateCashAccount(user auth.User, input CreateCashAccountInput) (BankAccount, error)
	CreateMoneyOperation(user auth.User, input CreateMoneyOperationInput) error
	ListMoneyDocuments(user auth.User, documentType string, search string) ([]MoneyDocumentSummary, error)
	GetMoneyDocument(user auth.User, documentID string) (MoneyDocumentDetail, error)
	SettleMoneyDocument(user auth.User, documentID string, input SettleMoneyDocumentInput) error
	ListServices(user auth.User) ([]Service, error)
	CreateService(user auth.User, input CreateServiceInput) (Service, error)
	UpdateService(user auth.User, serviceID string, input CreateServiceInput) (Service, error)
	DeleteService(user auth.User, serviceID string) error
	ListRecipes(user auth.User) ([]Recipe, error)
	CreateRecipe(user auth.User, input CreateRecipeInput) (Recipe, error)
	UpdateRecipe(user auth.User, recipeID string, input CreateRecipeInput) (Recipe, error)
	DeleteRecipe(user auth.User, recipeID string) error
	SetRecipePayrollAmount(user auth.User, recipeID string, amount int) error
	ListProductionOrders(user auth.User) ([]ProductionOrder, error)
	CreateProductionOrder(user auth.User, input CreateProductionOrderInput) (ProductionOrder, error)
	UpdateProductionOrderStatus(user auth.User, orderID string, input UpdateProductionOrderStatusInput) (ProductionOrder, error)
	ListEmployees(user auth.User) ([]Employee, error)
	CreateEmployee(user auth.User, input CreateEmployeeInput) (Employee, error)
	UpdateEmployee(user auth.User, employeeID string, input CreateEmployeeInput) (Employee, error)
	DeleteEmployee(user auth.User, employeeID string) error
	ListPayrollPeriods(user auth.User) ([]PayrollPeriod, error)
	CreatePayrollPeriod(user auth.User, input CreatePayrollPeriodInput) (PayrollPeriod, error)
	GetPayrollPeriod(user auth.User, periodID string) (PayrollPeriodDetail, error)
	DeletePayrollPeriod(user auth.User, periodID string) error
	CalculatePayroll(user auth.User, periodID string) (PayrollPeriodDetail, error)
	UpdatePayrollEntry(user auth.User, periodID string, entryID string, input UpdatePayrollEntryInput) (PayrollPeriodDetail, error)
	PayPayrollPeriod(user auth.User, periodID string, input PayPayrollPeriodInput) (PayrollPeriodDetail, error)
	ListUserCompanies(user auth.User) ([]CompanyMembership, error)
	CreateCompany(user auth.User, input CreateCompanyInput) (CompanyMembership, error)
	ListCompanyMembers(user auth.User, companyID string) ([]CompanyMember, error)
	AddCompanyMember(user auth.User, companyID string, input AddCompanyMemberInput) (CompanyMember, error)
	UpdateCompanyMemberRole(user auth.User, companyID string, memberUserID string, input UpdateCompanyMemberRoleInput) (CompanyMember, error)
	RemoveCompanyMember(user auth.User, companyID string, memberUserID string) error
	SetDefaultCompany(user auth.User, companyID string) error
	GetCompany(user auth.User, companyID string) (CompanyDetail, error)
	UpdateCompany(user auth.User, companyID string, input UpdateCompanyInput) (CompanyDetail, error)
	GetCompanyLogo(user auth.User, companyID string) ([]byte, error)
	UpdateCompanyLogo(user auth.User, companyID string, logoPNG []byte) (CompanyDetail, error)
}

type MemoryStore struct {
	mu                   sync.RWMutex
	clientsByUser        map[string][]Client
	warehousesByUser     map[string][]Warehouse
	productsByUser       map[string][]Product
	inventoryDocsByUser  map[string][]InventoryDocumentDetail
	financeByUser        map[string]Finance
	membersByCompany     map[string][]CompanyMember
	companyDetailsByID   map[string]CompanyDetail
	companyLogosByID     map[string][]byte
	companyLogoTimesByID map[string]time.Time
}

func NewMemoryStore() *MemoryStore {
	return &MemoryStore{
		clientsByUser:        make(map[string][]Client),
		warehousesByUser:     make(map[string][]Warehouse),
		productsByUser:       make(map[string][]Product),
		inventoryDocsByUser:  make(map[string][]InventoryDocumentDetail),
		financeByUser:        make(map[string]Finance),
		membersByCompany:     make(map[string][]CompanyMember),
		companyDetailsByID:   make(map[string]CompanyDetail),
		companyLogosByID:     make(map[string][]byte),
		companyLogoTimesByID: make(map[string]time.Time),
	}
}

func (s *MemoryStore) ListClients(user auth.User) ([]Client, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	clients := s.clientsByUser[user.ID]
	return cloneClients(clients), nil
}

func (s *MemoryStore) SaveClients(user auth.User, clients []Client) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	s.clientsByUser[user.ID] = cloneClients(clients)
	return nil
}

func (s *MemoryStore) ListWarehouses(user auth.User) ([]Warehouse, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	warehouses := s.ensureMemoryWarehouses(user.ID)
	return append([]Warehouse(nil), warehouses...), nil
}

func (s *MemoryStore) CreateWarehouse(user auth.User, input CreateWarehouseInput) (Warehouse, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	normalized := NormalizeWarehouseInput(input)
	if err := ValidateWarehouseInput(normalized); err != nil {
		return Warehouse{}, err
	}

	warehouses := s.ensureMemoryWarehouses(user.ID)
	for _, warehouse := range warehouses {
		if strings.EqualFold(warehouse.Name, normalized.Name) {
			return Warehouse{}, fmt.Errorf("%w: warehouse already exists", ErrValidation)
		}
	}

	warehouse := Warehouse{
		ID:        mustGenerateProductID(),
		Name:      normalized.Name,
		Code:      normalized.Code,
		IsDefault: false,
	}
	s.warehousesByUser[user.ID] = append([]Warehouse{warehouse}, warehouses...)
	return warehouse, nil
}

func (s *MemoryStore) ListWarehouseStock(user auth.User, warehouseID string, search string) ([]WarehouseStockItem, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	warehouse, ok := s.findMemoryWarehouse(user.ID, warehouseID)
	if !ok {
		return nil, fmt.Errorf("%w: warehouse not found", ErrValidation)
	}

	loweredSearch := strings.ToLower(strings.TrimSpace(search))
	items := make([]WarehouseStockItem, 0, len(s.productsByUser[user.ID]))
	for _, product := range s.productsByUser[user.ID] {
		if loweredSearch != "" &&
			!strings.Contains(strings.ToLower(product.Name), loweredSearch) &&
			!strings.Contains(strings.ToLower(product.SKU), loweredSearch) {
			continue
		}
		items = append(items, WarehouseStockItem{
			ProductID:   product.ID,
			ProductName: product.Name,
			SKU:         product.SKU,
			Category:    product.Category,
			UnitName:    product.UnitName,
			Available:   memoryWarehouseBalance(warehouse.Name, product),
			MinQuantity: product.MinQuantity,
			Status:      productStatus(memoryWarehouseBalance(warehouse.Name, product), product.MinQuantity),
		})
	}

	return items, nil
}

func (s *MemoryStore) ListWarehouseMovements(user auth.User, warehouseID string, search string) ([]WarehouseMovement, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	warehouse, ok := s.findMemoryWarehouse(user.ID, warehouseID)
	if !ok {
		return nil, fmt.Errorf("%w: warehouse not found", ErrValidation)
	}

	loweredSearch := strings.ToLower(strings.TrimSpace(search))
	movements := make([]WarehouseMovement, 0)
	for _, document := range s.inventoryDocsByUser[user.ID] {
		if document.Summary.WarehouseName != warehouse.Name && document.Summary.RelatedWarehouse != warehouse.Name {
			continue
		}
		for _, line := range document.Lines {
			movementType, quantity := memoryMovementForWarehouse(warehouse.Name, document.Summary)
			if quantity == 0 {
				continue
			}
			if loweredSearch != "" &&
				!strings.Contains(strings.ToLower(document.Summary.DocumentNo), loweredSearch) &&
				!strings.Contains(strings.ToLower(line.ItemName), loweredSearch) &&
				!strings.Contains(strings.ToLower(line.SKU), loweredSearch) {
				continue
			}
			movements = append(movements, WarehouseMovement{
				ID:               fmt.Sprintf("%s-%s", document.Summary.ID, line.SKU),
				DocumentID:       document.Summary.ID,
				DocumentNo:       document.Summary.DocumentNo,
				DocumentType:     document.Summary.DocumentType,
				MovementType:     movementType,
				ProductName:      line.ItemName,
				SKU:              line.SKU,
				Quantity:         quantityForLine(quantity, line.Quantity),
				BalanceAfter:     balanceAfterForLine(warehouse.Name, line.SKU, document.Summary.DocumentNo, s.productsByUser[user.ID]),
				DocumentDate:     document.Summary.DocumentDate,
				WarehouseName:    document.Summary.WarehouseName,
				RelatedWarehouse: document.Summary.RelatedWarehouse,
			})
		}
	}

	return movements, nil
}

func (s *MemoryStore) ListWarehouseTurnover(user auth.User, warehouseID string, from string, to string) ([]WarehouseTurnoverItem, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if _, ok := s.findMemoryWarehouse(user.ID, warehouseID); !ok {
		return nil, fmt.Errorf("%w: warehouse not found", ErrValidation)
	}

	return []WarehouseTurnoverItem{}, nil
}

func (s *MemoryStore) FinancialSummary(user auth.User, from string, to string) (FinancialSummary, error) {
	return FinancialSummary{From: from, To: to}, nil
}

func (s *MemoryStore) CounterpartyStatement(user auth.User, clientID string, from string, to string) (CounterpartyStatement, error) {
	return CounterpartyStatement{ClientID: clientID, From: from, To: to, Entries: []CounterpartyStatementEntry{}}, nil
}

func (s *MemoryStore) ListProducts(user auth.User) ([]Product, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	products := s.productsByUser[user.ID]
	return cloneProducts(products), nil
}

func (s *MemoryStore) CreateProduct(user auth.User, input CreateProductInput) (Product, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	warehouses := s.ensureMemoryWarehouses(user.ID)
	defaultWarehouseName := warehouses[0].Name
	product := NewProductFromInput(input)
	if product.Quantity > 0 {
		documentNo := fmt.Sprintf("OPEN-%s", product.SKU)
		product.Movements = append(product.Movements, StockMovement{
			Date:     time.Now().Format("2 January 2006"),
			Document: documentNo,
			Quantity: product.Quantity,
			Balance:  product.Quantity,
		})
		s.inventoryDocsByUser[user.ID] = append(
			[]InventoryDocumentDetail{{
				Summary: InventoryDocumentSummary{
					ID:            mustGenerateProductID(),
					DocumentNo:    documentNo,
					DocumentType:  "opening",
					Status:        "posted",
					DocumentDate:  time.Now().Format("2006-01-02"),
					WarehouseName: defaultWarehouseName,
					ProductLines:  1,
					TotalQuantity: product.Quantity,
				},
				Lines: []InventoryDocumentLine{{
					ItemName:  product.Name,
					ItemType:  "product",
					SKU:       product.SKU,
					Quantity:  product.Quantity,
					UnitPrice: product.Price,
					UnitCost:  product.Cost,
					LineTotal: product.Quantity * product.Price,
				}},
			}},
			s.inventoryDocsByUser[user.ID]...,
		)
	}
	s.productsByUser[user.ID] = append([]Product{product}, s.productsByUser[user.ID]...)
	return cloneProducts([]Product{product})[0], nil
}

func (s *MemoryStore) UpdateProduct(user auth.User, productID string, input CreateProductInput) (Product, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	products := s.productsByUser[user.ID]
	for index := range products {
		if products[index].ID != productID {
			continue
		}

		products[index] = UpdatedProductFromInput(products[index], input)
		s.productsByUser[user.ID] = products
		return cloneProducts([]Product{products[index]})[0], nil
	}

	return Product{}, ErrValidation
}

func (s *MemoryStore) DeleteProduct(user auth.User, productID string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	products := s.productsByUser[user.ID]
	for index := range products {
		if products[index].ID != productID {
			continue
		}

		s.productsByUser[user.ID] = append(products[:index], products[index+1:]...)
		return nil
	}

	return ErrValidation
}

func (s *MemoryStore) CreateInventoryDocument(user auth.User, input CreateInventoryDocumentInput) (InventoryDocumentDetail, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	products := s.productsByUser[user.ID]
	if len(products) == 0 {
		return InventoryDocumentDetail{}, ErrValidation
	}

	normalized := NormalizeInventoryDocumentInput(input)
	status := normalized.Status
	if status == "" {
		status = "posted"
	}
	s.ensureMemoryWarehouses(user.ID)
	documentID := mustGenerateProductID()
	documentDate := time.Now().Format("2006-01-02")
	if normalized.DocumentDate != "" {
		documentDate = normalized.DocumentDate
	}
	documentNo := normalized.DocumentNo
	if documentNo == "" {
		documentNo = fmt.Sprintf("%s-%d", strings.ToUpper(normalized.DocumentType), time.Now().UnixNano())
	}
	warehouseName := defaultIfEmpty(normalized.WarehouseName, "Основной склад")
	if !s.hasMemoryWarehouseName(user.ID, warehouseName) {
		s.warehousesByUser[user.ID] = append(
			s.warehousesByUser[user.ID],
			Warehouse{ID: mustGenerateProductID(), Name: warehouseName},
		)
	}
	if normalized.RelatedWarehouseName != "" && !s.hasMemoryWarehouseName(user.ID, normalized.RelatedWarehouseName) {
		s.warehousesByUser[user.ID] = append(
			s.warehousesByUser[user.ID],
			Warehouse{ID: mustGenerateProductID(), Name: normalized.RelatedWarehouseName},
		)
	}
	clientName := ""
	if normalized.ClientID != "" {
		for _, client := range s.clientsByUser[user.ID] {
			if client.ID == normalized.ClientID {
				clientName = client.Name
				break
			}
		}
		if clientName == "" {
			return InventoryDocumentDetail{}, ErrValidation
		}
	}

	lines := make([]InventoryDocumentLine, 0, len(normalized.Lines))
	totalQuantity := 0
	totalAmount := 0
	for _, line := range normalized.Lines {
		index := -1
		for productIndex := range products {
			if products[productIndex].ID == line.ProductID {
				index = productIndex
				break
			}
		}
		if index < 0 {
			return InventoryDocumentDetail{}, ErrValidation
		}

		product := &products[index]
		unitPrice := line.UnitPrice
		if unitPrice == 0 {
			unitPrice = product.Price
		}
		unitCost := line.UnitCost
		if unitCost == 0 {
			unitCost = product.Cost
		}

		if status == "posted" {
			switch normalized.DocumentType {
			case "purchase_receipt":
				product.Quantity += line.Quantity
				product.Movements = append([]StockMovement{{
					Date:     documentDate,
					Document: documentNo,
					Quantity: line.Quantity,
					Balance:  product.Quantity,
				}}, product.Movements...)
			case "write_off", "sale_issue":
				if product.Quantity < line.Quantity {
					return InventoryDocumentDetail{}, ErrValidation
				}
				product.Quantity -= line.Quantity
				product.Movements = append([]StockMovement{{
					Date:     documentDate,
					Document: documentNo,
					Quantity: -line.Quantity,
					Balance:  product.Quantity,
				}}, product.Movements...)
			case "transfer":
				if product.Quantity < line.Quantity {
					return InventoryDocumentDetail{}, ErrValidation
				}
				product.Quantity -= line.Quantity
				product.Movements = append([]StockMovement{{
					Date:     documentDate,
					Document: documentNo,
					Quantity: -line.Quantity,
					Balance:  product.Quantity,
				}}, product.Movements...)
			case "adjustment":
				product.Quantity += line.Quantity
				product.Movements = append([]StockMovement{{
					Date:     documentDate,
					Document: documentNo,
					Quantity: line.Quantity,
					Balance:  product.Quantity,
				}}, product.Movements...)
			}
			product.Status = productStatus(product.Quantity, product.MinQuantity)
		}

		totalQuantity += line.Quantity
		totalAmount += line.Quantity * unitPrice
		lines = append(lines, InventoryDocumentLine{
			ProductID: line.ProductID,
			ItemName:  product.Name,
			ItemType:  "product",
			SKU:       product.SKU,
			Quantity:  line.Quantity,
			UnitPrice: unitPrice,
			UnitCost:  unitCost,
			LineTotal: line.Quantity * unitPrice,
			Note:      line.Note,
		})
	}

	s.productsByUser[user.ID] = products
	detail := InventoryDocumentDetail{
		Summary: InventoryDocumentSummary{
			ID:               documentID,
			DocumentNo:       documentNo,
			DocumentType:     normalized.DocumentType,
			Status:           status,
			DocumentDate:     documentDate,
			ClientID:         normalized.ClientID,
			EmployeeID:       normalized.EmployeeID,
			ClientName:       clientName,
			WarehouseName:    warehouseName,
			RelatedWarehouse: normalized.RelatedWarehouseName,
			ProductLines:     len(lines),
			TotalQuantity:    totalQuantity,
			TotalAmount:      totalAmount,
			Note:             normalized.Note,
		},
		Lines: lines,
	}
	s.inventoryDocsByUser[user.ID] = append([]InventoryDocumentDetail{detail}, s.inventoryDocsByUser[user.ID]...)
	if status == "posted" {
		s.linkInventoryDocumentToFinance(user.ID, detail)
	}
	return detail, nil
}

func (s *MemoryStore) ListInventoryDocuments(user auth.User, documentType string, search string) ([]InventoryDocumentSummary, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	documents := make([]InventoryDocumentSummary, 0, len(s.inventoryDocsByUser[user.ID]))
	for _, detail := range s.inventoryDocsByUser[user.ID] {
		document := detail.Summary
		if documentType != "" && document.DocumentType != documentType {
			continue
		}
		loweredSearch := strings.ToLower(strings.TrimSpace(search))
		if loweredSearch != "" &&
			!strings.Contains(strings.ToLower(document.DocumentNo), loweredSearch) &&
			!strings.Contains(strings.ToLower(document.WarehouseName), loweredSearch) &&
			!strings.Contains(strings.ToLower(document.ClientName), loweredSearch) &&
			!strings.Contains(strings.ToLower(document.Note), loweredSearch) {
			continue
		}
		documents = append(documents, document)
	}

	return documents, nil
}

func (s *MemoryStore) GetInventoryDocument(user auth.User, documentID string) (InventoryDocumentDetail, error) {
	for _, document := range s.inventoryDocsByUser[user.ID] {
		if document.Summary.ID == documentID {
			return document, nil
		}
	}
	return InventoryDocumentDetail{}, ErrValidation
}

func (s *MemoryStore) UpdateInventoryDocument(user auth.User, documentID string, input CreateInventoryDocumentInput) (InventoryDocumentDetail, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	documents := s.inventoryDocsByUser[user.ID]
	documentIndex := -1
	for index := range documents {
		if documents[index].Summary.ID == documentID {
			documentIndex = index
			break
		}
	}
	if documentIndex < 0 {
		return InventoryDocumentDetail{}, ErrValidation
	}
	if documents[documentIndex].Summary.Status != "draft" {
		return InventoryDocumentDetail{}, fmt.Errorf("%w: only draft inventory documents can be edited", ErrValidation)
	}

	normalized := NormalizeInventoryDocumentInput(input)
	documentNo := normalized.DocumentNo
	if documentNo == "" {
		documentNo = documents[documentIndex].Summary.DocumentNo
	}
	documentDate := normalized.DocumentDate
	if documentDate == "" {
		documentDate = documents[documentIndex].Summary.DocumentDate
	}
	warehouseName := defaultIfEmpty(normalized.WarehouseName, "Основной склад")
	clientName := ""
	if normalized.ClientID != "" {
		for _, client := range s.clientsByUser[user.ID] {
			if client.ID == normalized.ClientID {
				clientName = client.Name
				break
			}
		}
		if clientName == "" {
			return InventoryDocumentDetail{}, ErrValidation
		}
	}

	lines := make([]InventoryDocumentLine, 0, len(normalized.Lines))
	totalQuantity := 0
	totalAmount := 0
	for _, line := range normalized.Lines {
		unitPrice := line.UnitPrice
		unitCost := line.UnitCost
		if line.ServiceID != "" {
			lineTotal := line.Quantity * unitPrice
			totalQuantity += line.Quantity
			totalAmount += lineTotal
			lines = append(lines, InventoryDocumentLine{
				ServiceID: line.ServiceID,
				ItemName:  "Услуга",
				ItemType:  "service",
				Quantity:  line.Quantity,
				UnitPrice: unitPrice,
				UnitCost:  unitCost,
				LineTotal: lineTotal,
				Note:      line.Note,
			})
			continue
		}

		var product Product
		found := false
		for _, item := range s.productsByUser[user.ID] {
			if item.ID == line.ProductID {
				product = item
				found = true
				break
			}
		}
		if !found {
			return InventoryDocumentDetail{}, ErrValidation
		}
		if unitPrice == 0 {
			unitPrice = product.Price
		}
		if unitCost == 0 {
			unitCost = product.Cost
		}
		lineTotal := line.Quantity * unitPrice
		totalQuantity += line.Quantity
		totalAmount += lineTotal
		lines = append(lines, InventoryDocumentLine{
			ProductID: line.ProductID,
			ItemName:  product.Name,
			ItemType:  "product",
			SKU:       product.SKU,
			Quantity:  line.Quantity,
			UnitPrice: unitPrice,
			UnitCost:  unitCost,
			LineTotal: lineTotal,
			Note:      line.Note,
		})
	}

	updated := InventoryDocumentDetail{
		Summary: InventoryDocumentSummary{
			ID:               documentID,
			DocumentNo:       documentNo,
			DocumentType:     normalized.DocumentType,
			Status:           "draft",
			DocumentDate:     documentDate,
			ClientID:         normalized.ClientID,
			EmployeeID:       normalized.EmployeeID,
			ClientName:       clientName,
			WarehouseName:    warehouseName,
			RelatedWarehouse: normalized.RelatedWarehouseName,
			ProductLines:     len(lines),
			TotalQuantity:    totalQuantity,
			TotalAmount:      totalAmount,
			Note:             normalized.Note,
		},
		Lines: lines,
	}
	documents[documentIndex] = updated
	s.inventoryDocsByUser[user.ID] = documents
	return updated, nil
}

func (s *MemoryStore) PostInventoryDocument(user auth.User, documentID string) (InventoryDocumentDetail, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	documents := s.inventoryDocsByUser[user.ID]
	documentIndex := -1
	for index := range documents {
		if documents[index].Summary.ID == documentID {
			documentIndex = index
			break
		}
	}
	if documentIndex < 0 {
		return InventoryDocumentDetail{}, ErrValidation
	}
	detail := documents[documentIndex]
	if detail.Summary.Status != "draft" {
		return InventoryDocumentDetail{}, fmt.Errorf("%w: only draft inventory documents can be posted", ErrValidation)
	}

	products := s.productsByUser[user.ID]
	for _, line := range detail.Lines {
		if line.ProductID == "" {
			continue
		}
		index := -1
		for productIndex := range products {
			if products[productIndex].ID == line.ProductID {
				index = productIndex
				break
			}
		}
		if index < 0 {
			return InventoryDocumentDetail{}, ErrValidation
		}
		product := &products[index]
		switch detail.Summary.DocumentType {
		case "purchase_receipt", "adjustment":
			product.Quantity += line.Quantity
			product.Movements = append([]StockMovement{{
				Date:     detail.Summary.DocumentDate,
				Document: detail.Summary.DocumentNo,
				Quantity: line.Quantity,
				Balance:  product.Quantity,
			}}, product.Movements...)
		case "write_off", "sale_issue", "transfer":
			if product.Quantity < line.Quantity {
				return InventoryDocumentDetail{}, ErrValidation
			}
			product.Quantity -= line.Quantity
			product.Movements = append([]StockMovement{{
				Date:     detail.Summary.DocumentDate,
				Document: detail.Summary.DocumentNo,
				Quantity: -line.Quantity,
				Balance:  product.Quantity,
			}}, product.Movements...)
		}
		product.Status = productStatus(product.Quantity, product.MinQuantity)
	}

	detail.Summary.Status = "posted"
	documents[documentIndex] = detail
	s.productsByUser[user.ID] = products
	s.inventoryDocsByUser[user.ID] = documents
	s.linkInventoryDocumentToFinance(user.ID, detail)
	return detail, nil
}

func (s *MemoryStore) DeleteInventoryDocument(user auth.User, documentID string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	documents := s.inventoryDocsByUser[user.ID]
	for index := range documents {
		if documents[index].Summary.ID != documentID {
			continue
		}
		if documents[index].Summary.Status != "draft" {
			return fmt.Errorf("%w: only draft inventory documents can be deleted", ErrValidation)
		}
		s.inventoryDocsByUser[user.ID] = append(documents[:index], documents[index+1:]...)
		return nil
	}
	return ErrValidation
}

func (s *MemoryStore) linkInventoryDocumentToFinance(userID string, detail InventoryDocumentDetail) {
	if detail.Summary.ClientID == "" || detail.Summary.TotalAmount <= 0 {
		return
	}

	finance := s.financeByUser[userID]
	documentType := ""
	lineNote := ""
	switch detail.Summary.DocumentType {
	case "sale_issue":
		documentType = "sale_receivable"
		lineNote = "Дебиторская задолженность по продаже"
	case "purchase_receipt":
		documentType = "purchase_payable"
		lineNote = "Кредиторская задолженность по закупу"
	default:
		return
	}

	documentNo := fmt.Sprintf("FIN-%s", detail.Summary.DocumentNo)
	finance.Transactions = append([]Transaction{{
		Type:        documentType,
		Description: documentNo,
		Amount:      detail.Summary.TotalAmount,
		Category:    lineNote,
		Date:        detail.Summary.DocumentDate,
		Account:     detail.Summary.ClientName,
	}}, finance.Transactions...)
	s.financeByUser[userID] = finance

}

func (s *MemoryStore) GetFinance(user auth.User) (Finance, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	finance, ok := s.financeByUser[user.ID]
	if !ok {
		return Finance{}, nil
	}

	return cloneFinance(finance), nil
}

func (s *MemoryStore) CreateCashAccount(user auth.User, input CreateCashAccountInput) (BankAccount, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	normalized := NormalizeCashAccountInput(input)
	account := BankAccount{
		ID:      mustGenerateAccountID(),
		Name:    normalized.Name,
		Balance: normalized.OpeningBalance,
		Color:   accountColorForType(normalized.AccountType),
		Icon:    accountIconForType(normalized.AccountType),
	}

	finance := s.financeByUser[user.ID]
	finance.Accounts = append([]BankAccount{account}, finance.Accounts...)
	finance.TotalBalance += normalized.OpeningBalance
	s.financeByUser[user.ID] = finance

	return account, nil
}

func (s *MemoryStore) CreateMoneyOperation(user auth.User, input CreateMoneyOperationInput) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	finance := s.financeByUser[user.ID]
	accountIndex := -1
	counterpartyIndex := -1
	for index := range finance.Accounts {
		if finance.Accounts[index].ID == input.AccountID {
			accountIndex = index
		}
		if finance.Accounts[index].ID == input.CounterpartyAccountID {
			counterpartyIndex = index
		}
	}

	if accountIndex < 0 {
		return ErrValidation
	}

	operationDate := time.Now().Format("2 January")
	if input.OperationDate != "" {
		if parsed, err := time.Parse("2006-01-02", input.OperationDate); err == nil {
			operationDate = parsed.Format("2 January")
		}
	}

	switch input.Direction {
	case "income":
		finance.Accounts[accountIndex].Balance += input.Amount
		finance.TotalBalance += input.Amount
		finance.Income += input.Amount
		finance.Transactions = append([]Transaction{{
			Type:        "income",
			Description: defaultIfEmpty(input.Description, "Поступление"),
			Amount:      input.Amount,
			Category:    defaultIfEmpty(input.Category, "Поступления"),
			Date:        operationDate,
			Account:     finance.Accounts[accountIndex].Name,
		}}, finance.Transactions...)
	case "expense":
		finance.Accounts[accountIndex].Balance -= input.Amount
		finance.TotalBalance -= input.Amount
		finance.Expense += input.Amount
		finance.Transactions = append([]Transaction{{
			Type:        "expense",
			Description: defaultIfEmpty(input.Description, "Списание"),
			Amount:      input.Amount,
			Category:    defaultIfEmpty(input.Category, "Расходы"),
			Date:        operationDate,
			Account:     finance.Accounts[accountIndex].Name,
		}}, finance.Transactions...)
	case "transfer":
		if counterpartyIndex < 0 {
			return ErrValidation
		}
		finance.Accounts[accountIndex].Balance -= input.Amount
		finance.Accounts[counterpartyIndex].Balance += input.Amount
		finance.Income += input.Amount
		finance.Expense += input.Amount
		finance.Transactions = append([]Transaction{
			{
				Type:        "expense",
				Description: defaultIfEmpty(input.Description, "Перевод"),
				Amount:      input.Amount,
				Category:    "Переводы",
				Date:        operationDate,
				Account:     finance.Accounts[accountIndex].Name,
			},
			{
				Type:        "income",
				Description: defaultIfEmpty(input.Description, "Перевод"),
				Amount:      input.Amount,
				Category:    "Переводы",
				Date:        operationDate,
				Account:     finance.Accounts[counterpartyIndex].Name,
			},
		}, finance.Transactions...)
	}

	finance.CashFlows = buildMemoryCashFlows(finance.Income, finance.Expense)
	s.financeByUser[user.ID] = finance
	return nil
}

func (s *MemoryStore) ListMoneyDocuments(user auth.User, documentType string, search string) ([]MoneyDocumentSummary, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	finance := s.financeByUser[user.ID]
	documents := make([]MoneyDocumentSummary, 0, len(finance.Transactions))
	for _, transaction := range finance.Transactions {
		documents = append(documents, MoneyDocumentSummary{
			ID:             mustGenerateAccountID(),
			DocumentNo:     transaction.Description,
			DocumentType:   transaction.Type,
			Status:         "posted",
			OperationDate:  transaction.Date,
			Description:    transaction.Description,
			PrimaryAccount: transaction.Account,
			Amount:         transaction.Amount,
		})
	}

	return documents, nil
}

func (s *MemoryStore) GetMoneyDocument(user auth.User, documentID string) (MoneyDocumentDetail, error) {
	documents, _ := s.ListMoneyDocuments(user, "", "")
	if len(documents) == 0 {
		return MoneyDocumentDetail{}, ErrValidation
	}
	return MoneyDocumentDetail{
		Summary: documents[0],
		Lines: []MoneyDocumentLine{
			{
				Category: documents[0].DocumentType,
				Amount:   documents[0].Amount,
				Note:     documents[0].Description,
			},
		},
	}, nil
}

func (s *MemoryStore) SettleMoneyDocument(user auth.User, documentID string, input SettleMoneyDocumentInput) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	normalized := NormalizeSettleMoneyDocumentInput(input)
	if err := ValidateSettleMoneyDocumentInput(normalized); err != nil {
		return err
	}

	finance := s.financeByUser[user.ID]
	accountIndex := -1
	for index := range finance.Accounts {
		if finance.Accounts[index].ID == normalized.AccountID {
			accountIndex = index
			break
		}
	}
	if accountIndex < 0 {
		return ErrValidation
	}

	if input.Amount <= 0 {
		return ErrValidation
	}

	return nil
}

func cloneClients(clients []Client) []Client {
	cloned := make([]Client, 0, len(clients))
	for _, client := range clients {
		client.Interactions = append([]Interaction(nil), client.Interactions...)
		client.OpenDocuments = append([]ClientDebtDocument(nil), client.OpenDocuments...)
		client.Timeline = append([]ClientTimelineItem(nil), client.Timeline...)
		cloned = append(cloned, client)
	}
	return cloned
}

func cloneProducts(products []Product) []Product {
	cloned := make([]Product, 0, len(products))
	for _, product := range products {
		product.Movements = append([]StockMovement(nil), product.Movements...)
		cloned = append(cloned, product)
	}
	return cloned
}

func cloneFinance(finance Finance) Finance {
	finance.Accounts = append([]BankAccount(nil), finance.Accounts...)
	finance.ExpenseCategories = append([]ExpenseCategory(nil), finance.ExpenseCategories...)
	finance.Transactions = append([]Transaction(nil), finance.Transactions...)
	finance.CashFlows = append([]CashFlow(nil), finance.CashFlows...)
	return finance
}

func (s *MemoryStore) ensureMemoryWarehouses(userID string) []Warehouse {
	warehouses := s.warehousesByUser[userID]
	if len(warehouses) == 0 {
		warehouses = []Warehouse{{
			ID:        mustGenerateProductID(),
			Name:      "Основной склад",
			Code:      "MAIN",
			IsDefault: true,
		}}
		s.warehousesByUser[userID] = warehouses
	}
	return warehouses
}

func (s *MemoryStore) findMemoryWarehouse(userID string, warehouseID string) (Warehouse, bool) {
	for _, warehouse := range s.ensureMemoryWarehouses(userID) {
		if warehouse.ID == warehouseID {
			return warehouse, true
		}
	}
	return Warehouse{}, false
}

func (s *MemoryStore) hasMemoryWarehouseName(userID string, warehouseName string) bool {
	for _, warehouse := range s.ensureMemoryWarehouses(userID) {
		if strings.EqualFold(warehouse.Name, warehouseName) {
			return true
		}
	}
	return false
}

func memoryWarehouseBalance(warehouseName string, product Product) int {
	balance := 0
	for _, movement := range product.Movements {
		if movement.Document == "" {
			continue
		}
		balance = movement.Balance
	}
	return balance
}

func memoryMovementForWarehouse(warehouseName string, summary InventoryDocumentSummary) (string, int) {
	switch summary.DocumentType {
	case "purchase_receipt", "adjustment", "opening":
		if summary.WarehouseName == warehouseName {
			return "in", 1
		}
	case "write_off", "sale_issue":
		if summary.WarehouseName == warehouseName {
			return "out", -1
		}
	case "transfer":
		if summary.WarehouseName == warehouseName {
			return "transfer_out", -1
		}
		if summary.RelatedWarehouse == warehouseName {
			return "transfer_in", 1
		}
	}
	return "", 0
}

func quantityForLine(direction int, quantity int) int {
	if direction < 0 {
		return -quantity
	}
	return quantity
}

func balanceAfterForLine(warehouseName string, sku string, documentNo string, products []Product) int {
	for _, product := range products {
		if product.SKU != sku {
			continue
		}
		for _, movement := range product.Movements {
			if movement.Document == documentNo {
				return movement.Balance
			}
		}
	}
	return 0
}

func accountColorForType(accountType string) string {
	switch accountType {
	case "cash":
		return "#00A86B"
	case "card":
		return "#3B82F6"
	case "e_wallet":
		return "#8B5CF6"
	default:
		return "#F14635"
	}
}

func accountIconForType(accountType string) string {
	switch accountType {
	case "cash":
		return "💰"
	case "card":
		return "💳"
	case "e_wallet":
		return "📱"
	default:
		return "🏦"
	}
}

func defaultIfEmpty(value string, fallback string) string {
	if value == "" {
		return fallback
	}
	return value
}

func (s *MemoryStore) ListServices(_ auth.User) ([]Service, error) {
	return []Service{}, nil
}

func (s *MemoryStore) CreateService(_ auth.User, input CreateServiceInput) (Service, error) {
	normalized := NormalizeServiceInput(input)
	if err := ValidateServiceInput(normalized); err != nil {
		return Service{}, err
	}
	svc := Service{
		ID:            mustGenerateProductID(),
		Name:          normalized.Name,
		Description:   normalized.Description,
		Price:         normalized.Price,
		AllowedToSell: normalized.AllowedToSell,
		Materials:     []ServiceMaterial{},
	}
	for _, m := range normalized.Materials {
		svc.Materials = append(svc.Materials, ServiceMaterial{
			ID:                  mustGenerateProductID(),
			MaterialType:        m.MaterialType,
			ProductID:           m.ProductID,
			SubServiceID:        m.SubServiceID,
			ExternalServiceName: m.ExternalServiceName,
			Quantity:            m.Quantity,
			Cost:                m.Cost,
		})
	}
	return svc, nil
}

func (s *MemoryStore) UpdateService(_ auth.User, serviceID string, input CreateServiceInput) (Service, error) {
	normalized := NormalizeServiceInput(input)
	if err := ValidateServiceInput(normalized); err != nil {
		return Service{}, err
	}
	return Service{ID: serviceID, Name: normalized.Name, Description: normalized.Description, Price: normalized.Price, AllowedToSell: normalized.AllowedToSell, Materials: []ServiceMaterial{}}, nil
}

func (s *MemoryStore) DeleteService(_ auth.User, _ string) error {
	return nil
}

func (s *MemoryStore) ListRecipes(_ auth.User) ([]Recipe, error) {
	return []Recipe{}, nil
}

func (s *MemoryStore) CreateRecipe(_ auth.User, input CreateRecipeInput) (Recipe, error) {
	normalized := NormalizeRecipeInput(input)
	if err := ValidateRecipeInput(normalized); err != nil {
		return Recipe{}, err
	}
	return Recipe{
		ID:            mustGenerateProductID(),
		Name:          normalized.Name,
		Description:   normalized.Description,
		PayrollAmount: normalized.PayrollAmount,
		Ingredients:   []RecipeIngredient{},
		Services:      []RecipeService{},
		Outputs:       []RecipeOutput{},
	}, nil
}

func (s *MemoryStore) UpdateRecipe(_ auth.User, recipeID string, input CreateRecipeInput) (Recipe, error) {
	normalized := NormalizeRecipeInput(input)
	if err := ValidateRecipeInput(normalized); err != nil {
		return Recipe{}, err
	}
	return Recipe{
		ID: recipeID, Name: normalized.Name, Description: normalized.Description,
		PayrollAmount: normalized.PayrollAmount,
		Ingredients:   []RecipeIngredient{}, Services: []RecipeService{}, Outputs: []RecipeOutput{},
	}, nil
}

func (s *MemoryStore) DeleteRecipe(_ auth.User, _ string) error { return nil }

func (s *MemoryStore) SetRecipePayrollAmount(_ auth.User, _ string, _ int) error {
	return nil
}

func (s *MemoryStore) ListProductionOrders(_ auth.User) ([]ProductionOrder, error) {
	return []ProductionOrder{}, nil
}

func (s *MemoryStore) CreateProductionOrder(_ auth.User, input CreateProductionOrderInput) (ProductionOrder, error) {
	normalized := NormalizeProductionOrderInput(input)
	if err := ValidateProductionOrderInput(normalized); err != nil {
		return ProductionOrder{}, err
	}
	return ProductionOrder{
		ID:              mustGenerateProductID(),
		DocumentNo:      defaultIfEmpty(normalized.DocumentNo, fmt.Sprintf("PRD-%d", time.Now().UnixNano())),
		RecipeID:        normalized.RecipeID,
		PlannedQuantity: normalized.PlannedQuantity,
		Status:          "draft",
		CreatedAt:       time.Now().Format("2006-01-02"),
	}, nil
}

func (s *MemoryStore) UpdateProductionOrderStatus(_ auth.User, orderID string, input UpdateProductionOrderStatusInput) (ProductionOrder, error) {
	return ProductionOrder{ID: orderID, Status: input.Status}, nil
}

func (s *MemoryStore) ListEmployees(_ auth.User) ([]Employee, error) {
	return []Employee{}, nil
}

func (s *MemoryStore) CreateEmployee(_ auth.User, input CreateEmployeeInput) (Employee, error) {
	normalized := NormalizeEmployeeInput(input)
	if err := ValidateEmployeeInput(normalized); err != nil {
		return Employee{}, err
	}
	return Employee{
		ID:              mustGenerateProductID(),
		FullName:        normalized.FullName,
		Position:        normalized.Position,
		IIN:             normalized.IIN,
		Phone:           normalized.Phone,
		SalaryType:      normalized.SalaryType,
		MonthlySalary:   normalized.MonthlySalary,
		HourlyRate:      normalized.HourlyRate,
		PieceRate:       normalized.PieceRate,
		PieceRateSource: normalized.PieceRateSource,
		SalesPercent:    normalized.SalesPercent,
		SalesBasis:      normalized.SalesBasis,
		StandardDays:    normalized.StandardDays,
		HireDate:        normalized.HireDate,
		Status:          normalized.Status,
		Notes:           normalized.Notes,
	}, nil
}

func (s *MemoryStore) UpdateEmployee(_ auth.User, employeeID string, input CreateEmployeeInput) (Employee, error) {
	normalized := NormalizeEmployeeInput(input)
	if err := ValidateEmployeeInput(normalized); err != nil {
		return Employee{}, err
	}
	return Employee{
		ID:              employeeID,
		FullName:        normalized.FullName,
		Position:        normalized.Position,
		IIN:             normalized.IIN,
		Phone:           normalized.Phone,
		SalaryType:      normalized.SalaryType,
		MonthlySalary:   normalized.MonthlySalary,
		HourlyRate:      normalized.HourlyRate,
		PieceRate:       normalized.PieceRate,
		PieceRateSource: normalized.PieceRateSource,
		SalesPercent:    normalized.SalesPercent,
		SalesBasis:      normalized.SalesBasis,
		StandardDays:    normalized.StandardDays,
		HireDate:        normalized.HireDate,
		Status:          normalized.Status,
		Notes:           normalized.Notes,
	}, nil
}

func (s *MemoryStore) DeleteEmployee(_ auth.User, _ string) error { return nil }

func (s *MemoryStore) ListPayrollPeriods(_ auth.User) ([]PayrollPeriod, error) {
	return []PayrollPeriod{}, nil
}

func (s *MemoryStore) CreatePayrollPeriod(_ auth.User, input CreatePayrollPeriodInput) (PayrollPeriod, error) {
	normalized := NormalizePayrollPeriodInput(input)
	if err := ValidatePayrollPeriodInput(normalized); err != nil {
		return PayrollPeriod{}, err
	}
	return PayrollPeriod{
		ID:          mustGenerateProductID(),
		PeriodYear:  normalized.PeriodYear,
		PeriodMonth: normalized.PeriodMonth,
		Title:       normalized.Title,
		Status:      "draft",
		CreatedAt:   time.Now().Format("2006-01-02"),
	}, nil
}

func (s *MemoryStore) GetPayrollPeriod(_ auth.User, periodID string) (PayrollPeriodDetail, error) {
	return PayrollPeriodDetail{
		Period:  PayrollPeriod{ID: periodID, Status: "draft"},
		Entries: []PayrollEntry{},
	}, nil
}

func (s *MemoryStore) DeletePayrollPeriod(_ auth.User, _ string) error { return nil }

func (s *MemoryStore) CalculatePayroll(_ auth.User, periodID string) (PayrollPeriodDetail, error) {
	return PayrollPeriodDetail{
		Period:  PayrollPeriod{ID: periodID, Status: "calculated"},
		Entries: []PayrollEntry{},
	}, nil
}

func (s *MemoryStore) UpdatePayrollEntry(_ auth.User, periodID string, _ string, _ UpdatePayrollEntryInput) (PayrollPeriodDetail, error) {
	return PayrollPeriodDetail{
		Period:  PayrollPeriod{ID: periodID, Status: "calculated"},
		Entries: []PayrollEntry{},
	}, nil
}

func (s *MemoryStore) PayPayrollPeriod(_ auth.User, periodID string, _ PayPayrollPeriodInput) (PayrollPeriodDetail, error) {
	return PayrollPeriodDetail{
		Period:  PayrollPeriod{ID: periodID, Status: "paid"},
		Entries: []PayrollEntry{},
	}, nil
}

func (s *MemoryStore) ListUserCompanies(user auth.User) ([]CompanyMembership, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	if len(user.Companies) == 0 {
		company := CompanyMembership{
			ID:        "cmp_default",
			Name:      `ТОО "Мой Бизнес"`,
			Country:   "KZ",
			Role:      "owner",
			IsDefault: true,
		}
		if updatedAt, ok := s.companyLogoTimesByID[company.ID]; ok {
			company.LogoURL = companyLogoURL(company.ID, updatedAt)
		}
		return []CompanyMembership{company}, nil
	}
	companies := make([]CompanyMembership, 0, len(user.Companies))
	for index, company := range user.Companies {
		item := CompanyMembership{
			ID:        fmt.Sprintf("cmp_%d", index),
			Name:      company.Name,
			Country:   company.Country,
			IIN:       company.IIN,
			Role:      "owner",
			IsDefault: index == 0,
		}
		if updatedAt, ok := s.companyLogoTimesByID[item.ID]; ok {
			item.LogoURL = companyLogoURL(item.ID, updatedAt)
		}
		companies = append(companies, item)
	}
	return companies, nil
}

func (s *MemoryStore) CreateCompany(_ auth.User, input CreateCompanyInput) (CompanyMembership, error) {
	normalized := NormalizeCompanyInput(input)
	if err := ValidateCompanyInput(normalized); err != nil {
		return CompanyMembership{}, err
	}
	return CompanyMembership{
		ID:      "cmp_new",
		Name:    normalized.Name,
		Country: normalized.Country,
		IIN:     normalized.IIN,
		Role:    "owner",
	}, nil
}

func (s *MemoryStore) ListCompanyMembers(user auth.User, companyID string) ([]CompanyMember, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	members := s.ensureMemoryCompanyMembers(user, companyID)
	actorRole, ok := memoryActorRole(members, user.ID)
	if !ok || (actorRole != "owner" && actorRole != "admin") {
		return nil, fmt.Errorf("%w: forbidden", ErrValidation)
	}
	return append([]CompanyMember(nil), members...), nil
}

func (s *MemoryStore) AddCompanyMember(user auth.User, companyID string, input AddCompanyMemberInput) (CompanyMember, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	normalized := NormalizeAddCompanyMemberInput(input)
	if err := ValidateAddCompanyMemberInput(normalized); err != nil {
		return CompanyMember{}, err
	}

	members := s.ensureMemoryCompanyMembers(user, companyID)
	actorRole, ok := memoryActorRole(members, user.ID)
	if !ok || (actorRole != "owner" && actorRole != "admin") {
		return CompanyMember{}, fmt.Errorf("%w: forbidden", ErrValidation)
	}
	if normalized.Role == "owner" {
		return CompanyMember{}, fmt.Errorf("%w: owner role cannot be assigned", ErrValidation)
	}
	for index := range members {
		if members[index].Phone == normalized.Phone {
			if members[index].IsOwner {
				return CompanyMember{}, fmt.Errorf("%w: owner role cannot be changed", ErrValidation)
			}
			members[index].Role = normalized.Role
			members[index].RoleLabel = companyRoleLabel(normalized.Role)
			s.membersByCompany[companyID] = members
			return members[index], nil
		}
	}

	member := CompanyMember{
		UserID:        fmt.Sprintf("usr_%d", len(members)+1),
		FullName:      normalized.Phone,
		Phone:         normalized.Phone,
		Role:          normalized.Role,
		RoleLabel:     companyRoleLabel(normalized.Role),
		IsOwner:       false,
		IsCurrentUser: false,
		JoinedAt:      time.Now().Format(time.RFC3339),
	}
	s.membersByCompany[companyID] = append(members, member)
	return member, nil
}

func (s *MemoryStore) UpdateCompanyMemberRole(user auth.User, companyID string, memberUserID string, input UpdateCompanyMemberRoleInput) (CompanyMember, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	normalized := NormalizeUpdateCompanyMemberRoleInput(input)
	if err := ValidateUpdateCompanyMemberRoleInput(normalized); err != nil {
		return CompanyMember{}, err
	}

	members := s.ensureMemoryCompanyMembers(user, companyID)
	actorRole, ok := memoryActorRole(members, user.ID)
	if !ok || (actorRole != "owner" && actorRole != "admin") {
		return CompanyMember{}, fmt.Errorf("%w: forbidden", ErrValidation)
	}
	if normalized.Role == "owner" {
		return CompanyMember{}, fmt.Errorf("%w: owner role cannot be assigned", ErrValidation)
	}
	for index := range members {
		if members[index].UserID != memberUserID {
			continue
		}
		if members[index].IsOwner {
			return CompanyMember{}, fmt.Errorf("%w: owner role cannot be changed", ErrValidation)
		}
		if actorRole == "admin" && members[index].UserID == user.ID {
			return CompanyMember{}, fmt.Errorf("%w: admin cannot change own role", ErrValidation)
		}
		members[index].Role = normalized.Role
		members[index].RoleLabel = companyRoleLabel(normalized.Role)
		s.membersByCompany[companyID] = members
		return members[index], nil
	}
	return CompanyMember{}, fmt.Errorf("%w: member not found", ErrValidation)
}

func (s *MemoryStore) RemoveCompanyMember(user auth.User, companyID string, memberUserID string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	members := s.ensureMemoryCompanyMembers(user, companyID)
	actorRole, ok := memoryActorRole(members, user.ID)
	if !ok || (actorRole != "owner" && actorRole != "admin") {
		return fmt.Errorf("%w: forbidden", ErrValidation)
	}
	for index := range members {
		if members[index].UserID != memberUserID {
			continue
		}
		if members[index].IsOwner {
			return fmt.Errorf("%w: owner cannot be removed", ErrValidation)
		}
		if actorRole == "admin" && members[index].UserID == user.ID {
			return fmt.Errorf("%w: admin cannot remove self", ErrValidation)
		}
		s.membersByCompany[companyID] = append(members[:index], members[index+1:]...)
		return nil
	}
	return fmt.Errorf("%w: member not found", ErrValidation)
}

func (s *MemoryStore) SetDefaultCompany(_ auth.User, _ string) error {
	return nil
}

func (s *MemoryStore) GetCompany(user auth.User, companyID string) (CompanyDetail, error) {
	role := "owner"
	s.mu.Lock()
	defer s.mu.Unlock()
	members := s.ensureMemoryCompanyMembers(user, companyID)
	if actorRole, ok := memoryActorRole(members, user.ID); ok {
		role = actorRole
	}
	detail, ok := s.companyDetailsByID[companyID]
	if !ok {
		detail = CompanyDetail{
			ID:      companyID,
			Name:    "Тестовая компания",
			Country: "KZ",
		}
	}
	detail.Role = role
	if updatedAt, ok := s.companyLogoTimesByID[companyID]; ok {
		detail.LogoURL = companyLogoURL(companyID, updatedAt)
	}
	return detail, nil
}

func (s *MemoryStore) UpdateCompany(_ auth.User, companyID string, input UpdateCompanyInput) (CompanyDetail, error) {
	normalized := NormalizeUpdateCompanyInput(input)
	if err := ValidateUpdateCompanyInput(normalized); err != nil {
		return CompanyDetail{}, err
	}
	detail := CompanyDetail{
		ID:          companyID,
		Name:        normalized.Name,
		Country:     normalized.Country,
		IIN:         normalized.IIN,
		Email:       normalized.Email,
		Phone:       normalized.Phone,
		AddressLine: normalized.AddressLine,
		City:        normalized.City,
		BankName:    normalized.BankName,
		BankAccount: normalized.BankAccount,
		BankBik:     normalized.BankBik,
		Role:        "owner",
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	if updatedAt, ok := s.companyLogoTimesByID[companyID]; ok {
		detail.LogoURL = companyLogoURL(companyID, updatedAt)
	}
	s.companyDetailsByID[companyID] = detail
	return detail, nil
}

func (s *MemoryStore) GetCompanyLogo(_ auth.User, companyID string) ([]byte, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	data, ok := s.companyLogosByID[companyID]
	if !ok || len(data) == 0 {
		return nil, fmt.Errorf("%w: company logo not found", ErrValidation)
	}
	return append([]byte(nil), data...), nil
}

func (s *MemoryStore) UpdateCompanyLogo(_ auth.User, companyID string, logoPNG []byte) (CompanyDetail, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.companyLogosByID[companyID] = append([]byte(nil), logoPNG...)
	updatedAt := time.Now().UTC()
	s.companyLogoTimesByID[companyID] = updatedAt
	detail := s.companyDetailsByID[companyID]
	if detail.ID == "" {
		detail = CompanyDetail{
			ID:      companyID,
			Name:    "Тестовая компания",
			Country: "KZ",
			Role:    "owner",
		}
	}
	detail.LogoURL = companyLogoURL(companyID, updatedAt)
	s.companyDetailsByID[companyID] = detail
	return detail, nil
}

func buildMemoryCashFlows(income int, expense int) []CashFlow {
	flows := make([]CashFlow, 0, 3)
	if income > 0 {
		flows = append(flows, CashFlow{
			Title:       "Операционная деятельность",
			Subtitle:    "Приток",
			Value:       formatMoneyValue(income),
			Tone:        "#22C55E",
			ValueColor:  "#22C55E",
			Highlighted: false,
		})
	}
	if expense > 0 {
		flows = append(flows, CashFlow{
			Title:       "Операционная деятельность",
			Subtitle:    "Отток",
			Value:       formatMoneyValue(expense),
			Tone:        "#EF4444",
			ValueColor:  "#EF4444",
			Highlighted: false,
		})
	}
	netFlow := income - expense
	flows = append(flows, CashFlow{
		Title:       "Чистый денежный поток",
		Subtitle:    "За период",
		Value:       formatSignedMoneyValue(netFlow),
		Tone:        netFlowColor(netFlow),
		ValueColor:  netFlowColor(netFlow),
		Highlighted: true,
	})
	return flows
}

func (s *MemoryStore) ensureMemoryCompanyMembers(user auth.User, companyID string) []CompanyMember {
	members := s.membersByCompany[companyID]
	if len(members) == 0 {
		members = []CompanyMember{{
			UserID:        user.ID,
			FullName:      user.FullName,
			Phone:         user.Phone,
			Role:          "owner",
			RoleLabel:     companyRoleLabel("owner"),
			IsOwner:       true,
			IsCurrentUser: true,
			JoinedAt:      time.Now().Format(time.RFC3339),
		}}
		s.membersByCompany[companyID] = members
	}
	return members
}

func memoryActorRole(members []CompanyMember, userID string) (string, bool) {
	for _, member := range members {
		if member.UserID == userID {
			return member.Role, true
		}
	}
	return "", false
}
