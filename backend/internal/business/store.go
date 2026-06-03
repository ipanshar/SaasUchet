package business

import (
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
	ListInventoryDocuments(user auth.User, documentType string, search string) ([]InventoryDocumentSummary, error)
	GetFinance(user auth.User) (Finance, error)
	CreateCashAccount(user auth.User, input CreateCashAccountInput) (BankAccount, error)
	CreateMoneyOperation(user auth.User, input CreateMoneyOperationInput) error
	ListMoneyDocuments(user auth.User, documentType string, search string) ([]MoneyDocumentSummary, error)
}

type MemoryStore struct {
	mu             sync.RWMutex
	clientsByUser  map[string][]Client
	productsByUser map[string][]Product
	financeByUser  map[string]Finance
}

func NewMemoryStore() *MemoryStore {
	return &MemoryStore{
		clientsByUser:  make(map[string][]Client),
		productsByUser: make(map[string][]Product),
		financeByUser:  make(map[string]Finance),
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

func (s *MemoryStore) ListInventoryDocuments(user auth.User, documentType string, search string) ([]InventoryDocumentSummary, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	documents := make([]InventoryDocumentSummary, 0)
	for _, product := range s.productsByUser[user.ID] {
		for _, movement := range product.Movements {
			documents = append(documents, InventoryDocumentSummary{
				ID:            mustGenerateProductID(),
				DocumentNo:    movement.Document,
				DocumentType:  "movement",
				Status:        "posted",
				DocumentDate:  movement.Date,
				WarehouseName: "Основной склад",
				ProductLines:  1,
				TotalQuantity: absInt(movement.Quantity),
			})
		}
	}

	return documents, nil
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

func cloneClients(clients []Client) []Client {
	cloned := make([]Client, 0, len(clients))
	for _, client := range clients {
		client.Interactions = append([]Interaction(nil), client.Interactions...)
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
