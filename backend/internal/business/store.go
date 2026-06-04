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
	ListProducts(user auth.User) ([]Product, error)
	CreateProduct(user auth.User, input CreateProductInput) (Product, error)
	UpdateProduct(user auth.User, productID string, input CreateProductInput) (Product, error)
	DeleteProduct(user auth.User, productID string) error
	CreateInventoryDocument(user auth.User, input CreateInventoryDocumentInput) (InventoryDocumentDetail, error)
	ListInventoryDocuments(user auth.User, documentType string, search string) ([]InventoryDocumentSummary, error)
	GetInventoryDocument(user auth.User, documentID string) (InventoryDocumentDetail, error)
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
}

type MemoryStore struct {
	mu                  sync.RWMutex
	clientsByUser       map[string][]Client
	productsByUser      map[string][]Product
	inventoryDocsByUser map[string][]InventoryDocumentDetail
	financeByUser       map[string]Finance
}

func NewMemoryStore() *MemoryStore {
	return &MemoryStore{
		clientsByUser:       make(map[string][]Client),
		productsByUser:      make(map[string][]Product),
		inventoryDocsByUser: make(map[string][]InventoryDocumentDetail),
		financeByUser:       make(map[string]Finance),
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

func (s *MemoryStore) ListProducts(user auth.User) ([]Product, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	products := s.productsByUser[user.ID]
	return cloneProducts(products), nil
}

func (s *MemoryStore) CreateProduct(user auth.User, input CreateProductInput) (Product, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

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
					WarehouseName: "Основной склад",
					ProductLines:  1,
					TotalQuantity: product.Quantity,
				},
				Lines: []InventoryDocumentLine{{
					ProductName: product.Name,
					SKU:         product.SKU,
					Quantity:    product.Quantity,
					UnitPrice:   product.Price,
					UnitCost:    product.Cost,
					LineTotal:   product.Quantity * product.Price,
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

		totalQuantity += line.Quantity
		totalAmount += line.Quantity * unitPrice
		lines = append(lines, InventoryDocumentLine{
			ProductName: product.Name,
			SKU:         product.SKU,
			Quantity:    line.Quantity,
			UnitPrice:   unitPrice,
			UnitCost:    unitCost,
			LineTotal:   line.Quantity * unitPrice,
			Note:        line.Note,
		})
	}

	s.productsByUser[user.ID] = products
	detail := InventoryDocumentDetail{
		Summary: InventoryDocumentSummary{
			ID:               documentID,
			DocumentNo:       documentNo,
			DocumentType:     normalized.DocumentType,
			Status:           "posted",
			DocumentDate:     documentDate,
			ClientID:         normalized.ClientID,
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
	s.linkInventoryDocumentToFinance(user.ID, detail)
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
