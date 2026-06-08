package business

import (
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"regexp"
	"strings"
	"time"

	"github.com/altyncloud/saas-uchet/backend/internal/auth"
)

var (
	ErrValidation = errors.New("validation failed")
	digitsOnly    = regexp.MustCompile(`\D`)
)

type Overview struct {
	CompanyName       string        `json:"company_name"`
	Initials          string        `json:"initials"`
	Dashboard         Dashboard     `json:"dashboard"`
	RecentActivities  []Activity    `json:"recent_activities"`
	Clients           []Client      `json:"clients"`
	Products          []Product     `json:"products"`
	Finance           Finance       `json:"finance"`
	Staff             []StaffMember `json:"staff"`
	MenuNotifications int           `json:"menu_notifications"`
}

type Dashboard struct {
	MonthlyRevenue string       `json:"monthly_revenue"`
	RevenueChange  string       `json:"revenue_change"`
	KPIs           []KPI        `json:"kpis"`
	SalesSeries    []ChartPoint `json:"sales_series"`
}

type KPI struct {
	Title      string `json:"title"`
	Value      string `json:"value"`
	Change     string `json:"change"`
	ChangeTone string `json:"change_tone"`
	Icon       string `json:"icon"`
	IconTone   string `json:"icon_tone"`
}

type ChartPoint struct {
	Label string  `json:"label"`
	Value float64 `json:"value"`
}

type Activity struct {
	Title  string `json:"title"`
	Amount string `json:"amount"`
	Time   string `json:"time"`
	Icon   string `json:"icon"`
	Tone   string `json:"tone"`
}

type Client struct {
	ID            string               `json:"id"`
	Name          string               `json:"name"`
	Contact       string               `json:"contact"`
	Phone         string               `json:"phone"`
	Email         string               `json:"email"`
	Segment       string               `json:"segment"`
	TotalSales    int                  `json:"total_sales"`
	Debt          int                  `json:"debt"`
	Receivable    int                  `json:"receivable"`
	Payable       int                  `json:"payable"`
	SalesCount    int                  `json:"sales_count"`
	AverageSale   int                  `json:"average_sale"`
	PaymentsIn    int                  `json:"payments_in"`
	PaymentsOut   int                  `json:"payments_out"`
	OverdueAmount int                  `json:"overdue_amount"`
	BIN           string               `json:"bin,omitempty"`
	IIN           string               `json:"iin,omitempty"`
	Interactions  []Interaction        `json:"interactions"`
	OpenDocuments []ClientDebtDocument `json:"open_documents"`
	Timeline      []ClientTimelineItem `json:"timeline"`
}

type ClientDebtDocument struct {
	DocumentID      string `json:"document_id"`
	DocumentNo      string `json:"document_no"`
	DocumentType    string `json:"document_type"`
	Status          string `json:"status"`
	OperationDate   string `json:"operation_date"`
	Amount          int    `json:"amount"`
	PaidAmount      int    `json:"paid_amount"`
	RemainingAmount int    `json:"remaining_amount"`
}

type ClientTimelineItem struct {
	DocumentID   string `json:"document_id"`
	DocumentType string `json:"document_type"`
	EventType    string `json:"event_type"`
	Title        string `json:"title"`
	Subtitle     string `json:"subtitle"`
	EventDate    string `json:"event_date"`
	Amount       int    `json:"amount"`
	Tone         string `json:"tone"`
}

type CreateClientInput struct {
	Name    string `json:"name"`
	Contact string `json:"contact"`
	Phone   string `json:"phone"`
	Email   string `json:"email"`
	Segment string `json:"segment"`
	BIN     string `json:"bin,omitempty"`
	IIN     string `json:"iin,omitempty"`
}

type Interaction struct {
	Title string `json:"title"`
	Date  string `json:"date"`
	Note  string `json:"note"`
}

type Product struct {
	ID            string          `json:"id"`
	Name          string          `json:"name"`
	SKU           string          `json:"sku"`
	Category      string          `json:"category"`
	ProductType   string          `json:"product_type"`
	UnitName      string          `json:"unit_name"`
	AllowedToSell bool            `json:"allowed_to_sell"`
	Quantity      int             `json:"quantity"`
	MinQuantity   int             `json:"min_quantity"`
	Price         int             `json:"price"`
	Cost          int             `json:"cost"`
	Barcode       string          `json:"barcode"`
	Status        string          `json:"status"`
	Movements     []StockMovement `json:"movements"`
}

type CreateProductInput struct {
	Name            string `json:"name"`
	SKU             string `json:"sku"`
	Category        string `json:"category"`
	ProductType     string `json:"product_type"`
	UnitName        string `json:"unit_name"`
	AllowedToSell   bool   `json:"allowed_to_sell"`
	InitialQuantity int    `json:"initial_quantity"`
	MinQuantity     int    `json:"min_quantity"`
	Price           int    `json:"price"`
	Cost            int    `json:"cost"`
	Barcode         string `json:"barcode"`
}

type Service struct {
	ID            string            `json:"id"`
	Name          string            `json:"name"`
	Description   string            `json:"description"`
	Price         float64           `json:"price"`
	AllowedToSell bool              `json:"allowed_to_sell"`
	Materials     []ServiceMaterial `json:"materials"`
}

type ServiceMaterial struct {
	ID                  string  `json:"id"`
	MaterialType        string  `json:"material_type"`
	ProductID           string  `json:"product_id,omitempty"`
	ProductName         string  `json:"product_name,omitempty"`
	SubServiceID        string  `json:"sub_service_id,omitempty"`
	SubServiceName      string  `json:"sub_service_name,omitempty"`
	ExternalServiceName string  `json:"external_service_name,omitempty"`
	Quantity            float64 `json:"quantity"`
	Cost                float64 `json:"cost"`
}

type CreateServiceMaterialInput struct {
	MaterialType        string  `json:"material_type"`
	ProductID           string  `json:"product_id,omitempty"`
	SubServiceID        string  `json:"sub_service_id,omitempty"`
	ExternalServiceName string  `json:"external_service_name,omitempty"`
	Quantity            float64 `json:"quantity"`
	Cost                float64 `json:"cost"`
}

type CreateServiceInput struct {
	Name          string                       `json:"name"`
	Description   string                       `json:"description"`
	Price         float64                      `json:"price"`
	AllowedToSell bool                         `json:"allowed_to_sell"`
	Materials     []CreateServiceMaterialInput `json:"materials"`
}

type CreateInventoryDocumentLineInput struct {
	ProductID string `json:"product_id"`
	ServiceID string `json:"service_id"`
	Quantity  int    `json:"quantity"`
	UnitPrice int    `json:"unit_price"`
	UnitCost  int    `json:"unit_cost"`
	Note      string `json:"note"`
}

type Warehouse struct {
	ID        string `json:"id"`
	Name      string `json:"name"`
	Code      string `json:"code,omitempty"`
	IsDefault bool   `json:"is_default"`
}

type CreateWarehouseInput struct {
	Name string `json:"name"`
	Code string `json:"code,omitempty"`
}

type WarehouseStockItem struct {
	ProductID   string `json:"product_id"`
	ProductName string `json:"product_name"`
	SKU         string `json:"sku"`
	Category    string `json:"category"`
	UnitName    string `json:"unit_name"`
	Available   int    `json:"available"`
	MinQuantity int    `json:"min_quantity"`
	Status      string `json:"status"`
}

type WarehouseMovement struct {
	ID               string `json:"id"`
	DocumentID       string `json:"document_id"`
	DocumentNo       string `json:"document_no"`
	DocumentType     string `json:"document_type"`
	MovementType     string `json:"movement_type"`
	ProductID        string `json:"product_id"`
	ProductName      string `json:"product_name"`
	SKU              string `json:"sku"`
	Quantity         int    `json:"quantity"`
	BalanceAfter     int    `json:"balance_after"`
	DocumentDate     string `json:"document_date"`
	WarehouseName    string `json:"warehouse_name"`
	RelatedWarehouse string `json:"related_warehouse_name,omitempty"`
}

type CreateInventoryDocumentInput struct {
	DocumentType         string                             `json:"document_type"`
	DocumentDate         string                             `json:"document_date,omitempty"`
	DocumentNo           string                             `json:"document_no,omitempty"`
	WarehouseName        string                             `json:"warehouse_name,omitempty"`
	RelatedWarehouseName string                             `json:"related_warehouse_name,omitempty"`
	ClientID             string                             `json:"client_id,omitempty"`
	Note                 string                             `json:"note,omitempty"`
	Lines                []CreateInventoryDocumentLineInput `json:"lines"`
}

type StockMovement struct {
	Date     string `json:"date"`
	Document string `json:"document"`
	Quantity int    `json:"quantity"`
	Balance  int    `json:"balance"`
}

type InventoryDocumentSummary struct {
	ID               string `json:"id"`
	DocumentNo       string `json:"document_no"`
	DocumentType     string `json:"document_type"`
	Status           string `json:"status"`
	DocumentDate     string `json:"document_date"`
	WarehouseName    string `json:"warehouse_name"`
	RelatedWarehouse string `json:"related_warehouse_name,omitempty"`
	ClientID         string `json:"client_id,omitempty"`
	ClientName       string `json:"client_name,omitempty"`
	ProductLines     int    `json:"product_lines"`
	TotalQuantity    int    `json:"total_quantity"`
	TotalAmount      int    `json:"total_amount"`
	Note             string `json:"note,omitempty"`
}

type InventoryDocumentLine struct {
	ItemName  string `json:"item_name"`
	ItemType  string `json:"item_type"` // product | service
	SKU       string `json:"sku,omitempty"`
	Quantity  int    `json:"quantity"`
	UnitPrice int    `json:"unit_price"`
	UnitCost  int    `json:"unit_cost"`
	LineTotal int    `json:"line_total"`
	Note      string `json:"note,omitempty"`
}

type InventoryDocumentDetail struct {
	Summary InventoryDocumentSummary `json:"summary"`
	Lines   []InventoryDocumentLine  `json:"lines"`
}

type Finance struct {
	TotalBalance      int               `json:"total_balance"`
	Income            int               `json:"income"`
	Expense           int               `json:"expense"`
	Accounts          []BankAccount     `json:"accounts"`
	ExpenseCategories []ExpenseCategory `json:"expense_categories"`
	Transactions      []Transaction     `json:"transactions"`
	CashFlows         []CashFlow        `json:"cash_flows"`
}

type CreateCashAccountInput struct {
	Name           string `json:"name"`
	AccountType    string `json:"account_type"`
	CurrencyCode   string `json:"currency_code"`
	BankName       string `json:"bank_name"`
	IBAN           string `json:"iban"`
	BIK            string `json:"bik"`
	OpeningBalance int    `json:"opening_balance"`
}

type CreateMoneyOperationInput struct {
	AccountID             string `json:"account_id"`
	CounterpartyAccountID string `json:"counterparty_account_id,omitempty"`
	Direction             string `json:"direction"`
	Amount                int    `json:"amount"`
	Category              string `json:"category"`
	Description           string `json:"description"`
	ClientID              string `json:"client_id,omitempty"`
	OperationDate         string `json:"operation_date,omitempty"`
}

type SettleMoneyDocumentInput struct {
	AccountID     string `json:"account_id"`
	Amount        int    `json:"amount"`
	OperationDate string `json:"operation_date,omitempty"`
	Description   string `json:"description,omitempty"`
}

type BankAccount struct {
	ID      string `json:"id,omitempty"`
	Name    string `json:"name"`
	Balance int    `json:"balance"`
	Color   string `json:"color"`
	Icon    string `json:"icon"`
}

type ExpenseCategory struct {
	Name  string `json:"name"`
	Value int    `json:"value"`
	Color string `json:"color"`
}

type Transaction struct {
	Type        string `json:"type"`
	Description string `json:"description"`
	Amount      int    `json:"amount"`
	Category    string `json:"category"`
	Date        string `json:"date"`
	Account     string `json:"account"`
}

type MoneyDocumentSummary struct {
	ID               string `json:"id"`
	DocumentNo       string `json:"document_no"`
	DocumentType     string `json:"document_type"`
	Status           string `json:"status"`
	OperationDate    string `json:"operation_date"`
	Description      string `json:"description"`
	PrimaryAccount   string `json:"primary_account"`
	SecondaryAccount string `json:"secondary_account,omitempty"`
	Amount           int    `json:"amount"`
	PaidAmount       int    `json:"paid_amount"`
	RemainingAmount  int    `json:"remaining_amount"`
}

type MoneyDocumentLine struct {
	Category string `json:"category"`
	Amount   int    `json:"amount"`
	Note     string `json:"note,omitempty"`
}

type MoneyDocumentDetail struct {
	Summary MoneyDocumentSummary `json:"summary"`
	Lines   []MoneyDocumentLine  `json:"lines"`
}

type CashFlow struct {
	Title       string `json:"title"`
	Subtitle    string `json:"subtitle"`
	Value       string `json:"value"`
	Tone        string `json:"tone"`
	ValueColor  string `json:"value_color"`
	Highlighted bool   `json:"highlighted"`
}

type StaffMember struct {
	Name string `json:"name"`
	Role string `json:"role"`
}

func buildOverview(user auth.User, companyName string, clients []Client, products []Product, finance Finance) Overview {
	if strings.TrimSpace(companyName) == "" {
		companyName = `ТОО "Мой Бизнес"`
		if len(user.Companies) > 0 {
			companyName = user.Companies[0].Name
		}
	}

	return Overview{
		CompanyName:       companyName,
		Initials:          initialsOf(companyName),
		MenuNotifications: 5,
		Dashboard: Dashboard{
			MonthlyRevenue: "₸ 2,450,000",
			RevenueChange:  "+12.5%",
			KPIs: []KPI{
				{Title: "Продажи за день", Value: "₸ 125,000", Change: "+8.2%", ChangeTone: "success", Icon: "cart", IconTone: "success"},
				{Title: "Дебиторка", Value: "₸ 456,000", Change: "-3.1%", ChangeTone: "warning", Icon: "receipt", IconTone: "warning"},
				{Title: "Клиенты", Value: "1,234", Change: "+45", ChangeTone: "success", Icon: "group", IconTone: "info"},
				{Title: "Товары", Value: "5,678", Change: "56 новых", ChangeTone: "neutral", Icon: "inventory", IconTone: "primary"},
			},
			SalesSeries: []ChartPoint{
				{Label: "1 июн", Value: 45},
				{Label: "5 июн", Value: 52},
				{Label: "10", Value: 48},
				{Label: "15", Value: 61},
				{Label: "20", Value: 55},
				{Label: "25", Value: 67},
				{Label: "Сегодня", Value: 73},
			},
		},
		RecentActivities: []Activity{
			{Title: `ТОО "Астана Трейд"`, Amount: "₸ 125,000", Time: "10 минут назад", Icon: "cart", Tone: "success"},
			{Title: `ТОО "Поставщик+"`, Amount: "₸ 45,000", Time: "1 час назад", Icon: "inventory", Tone: "warning"},
			{Title: `ИП Нурланов А.Б.`, Amount: "₸ 89,500", Time: "2 часа назад", Icon: "payments", Tone: "success"},
			{Title: `ТОО "Алматы Опт"`, Amount: "₸ 156,000", Time: "3 часа назад", Icon: "description", Tone: "info"},
		},
		Clients:  clients,
		Products: products,
		Finance:  finance,
		Staff: []StaffMember{
			{Name: user.FullName, Role: "Администратор"},
			{Name: "Касымова Айгуль", Role: "Менеджер"},
			{Name: "Ибрагимов Ерлан", Role: "Кладовщик"},
		},
	}
}

func NormalizeClientInput(input CreateClientInput) CreateClientInput {
	input.Name = strings.TrimSpace(input.Name)
	input.Contact = strings.TrimSpace(input.Contact)
	input.Phone = normalizePhone(input.Phone)
	input.Email = strings.TrimSpace(strings.ToLower(input.Email))
	input.Segment = strings.TrimSpace(input.Segment)
	input.BIN = normalizeDigits(input.BIN)
	input.IIN = normalizeDigits(input.IIN)

	if input.Segment == "" {
		input.Segment = "Regular"
	}

	return input
}

func ValidateClientInput(input CreateClientInput) error {
	if strings.TrimSpace(input.Name) == "" {
		return fmt.Errorf("%w: client name is required", ErrValidation)
	}

	if strings.TrimSpace(input.Contact) == "" {
		return fmt.Errorf("%w: client contact is required", ErrValidation)
	}

	if normalizePhone(input.Phone) == "" {
		return fmt.Errorf("%w: client phone is required", ErrValidation)
	}

	if input.Email != "" && !strings.Contains(input.Email, "@") {
		return fmt.Errorf("%w: client email is invalid", ErrValidation)
	}

	if input.BIN != "" && len(input.BIN) != 12 {
		return fmt.Errorf("%w: BIN must contain 12 digits", ErrValidation)
	}

	if input.IIN != "" && len(input.IIN) != 12 {
		return fmt.Errorf("%w: IIN must contain 12 digits", ErrValidation)
	}

	return nil
}

func NewClientFromInput(input CreateClientInput) Client {
	normalized := NormalizeClientInput(input)
	return Client{
		ID:            mustGenerateClientID(),
		Name:          normalized.Name,
		Contact:       normalized.Contact,
		Phone:         normalized.Phone,
		Email:         normalized.Email,
		Segment:       normalized.Segment,
		BIN:           normalized.BIN,
		IIN:           normalized.IIN,
		TotalSales:    0,
		Debt:          0,
		Receivable:    0,
		Payable:       0,
		SalesCount:    0,
		AverageSale:   0,
		PaymentsIn:    0,
		PaymentsOut:   0,
		OverdueAmount: 0,
		Interactions:  []Interaction{},
		OpenDocuments: []ClientDebtDocument{},
		Timeline:      []ClientTimelineItem{},
	}
}

func UpdatedClientFromInput(existing Client, input CreateClientInput) Client {
	normalized := NormalizeClientInput(input)
	existing.Name = normalized.Name
	existing.Contact = normalized.Contact
	existing.Phone = normalized.Phone
	existing.Email = normalized.Email
	existing.Segment = normalized.Segment
	existing.BIN = normalized.BIN
	existing.IIN = normalized.IIN
	return existing
}

func NormalizeProductInput(input CreateProductInput) CreateProductInput {
	input.Name = strings.TrimSpace(input.Name)
	input.SKU = strings.TrimSpace(strings.ToUpper(input.SKU))
	input.Category = strings.TrimSpace(input.Category)
	input.Barcode = normalizeDigits(input.Barcode)
	input.UnitName = strings.TrimSpace(input.UnitName)
	input.ProductType = strings.TrimSpace(input.ProductType)
	if input.UnitName == "" {
		input.UnitName = "шт"
	}
	if input.ProductType == "" {
		input.ProductType = "consumer_goods"
	}
	return input
}

func NormalizeServiceInput(input CreateServiceInput) CreateServiceInput {
	input.Name = strings.TrimSpace(input.Name)
	input.Description = strings.TrimSpace(input.Description)
	if input.Price < 0 {
		input.Price = 0
	}
	for i := range input.Materials {
		input.Materials[i].MaterialType = strings.TrimSpace(input.Materials[i].MaterialType)
		input.Materials[i].ExternalServiceName = strings.TrimSpace(input.Materials[i].ExternalServiceName)
		if input.Materials[i].Quantity <= 0 {
			input.Materials[i].Quantity = 1
		}
		if input.Materials[i].Cost < 0 {
			input.Materials[i].Cost = 0
		}
	}
	return input
}

func NormalizeInventoryDocumentInput(input CreateInventoryDocumentInput) CreateInventoryDocumentInput {
	input.DocumentType = strings.TrimSpace(strings.ToLower(input.DocumentType))
	input.DocumentDate = strings.TrimSpace(input.DocumentDate)
	input.DocumentNo = strings.TrimSpace(strings.ToUpper(input.DocumentNo))
	input.WarehouseName = strings.TrimSpace(input.WarehouseName)
	input.RelatedWarehouseName = strings.TrimSpace(input.RelatedWarehouseName)
	input.ClientID = strings.TrimSpace(input.ClientID)
	input.Note = strings.TrimSpace(input.Note)

	for index := range input.Lines {
		input.Lines[index].ProductID = strings.TrimSpace(input.Lines[index].ProductID)
		input.Lines[index].Note = strings.TrimSpace(input.Lines[index].Note)
	}

	return input
}

func NormalizeWarehouseInput(input CreateWarehouseInput) CreateWarehouseInput {
	input.Name = strings.TrimSpace(input.Name)
	input.Code = strings.TrimSpace(strings.ToUpper(input.Code))
	return input
}

func NormalizeCashAccountInput(input CreateCashAccountInput) CreateCashAccountInput {
	input.Name = strings.TrimSpace(input.Name)
	input.AccountType = strings.TrimSpace(strings.ToLower(input.AccountType))
	input.CurrencyCode = strings.TrimSpace(strings.ToUpper(input.CurrencyCode))
	input.BankName = strings.TrimSpace(input.BankName)
	input.IBAN = strings.TrimSpace(strings.ToUpper(input.IBAN))
	input.BIK = strings.TrimSpace(strings.ToUpper(input.BIK))
	if input.CurrencyCode == "" {
		input.CurrencyCode = "KZT"
	}
	if input.AccountType == "" {
		input.AccountType = "bank"
	}
	return input
}

func NormalizeMoneyOperationInput(input CreateMoneyOperationInput) CreateMoneyOperationInput {
	input.AccountID = strings.TrimSpace(input.AccountID)
	input.CounterpartyAccountID = strings.TrimSpace(input.CounterpartyAccountID)
	input.Direction = strings.TrimSpace(strings.ToLower(input.Direction))
	input.Category = strings.TrimSpace(input.Category)
	input.Description = strings.TrimSpace(input.Description)
	input.ClientID = strings.TrimSpace(input.ClientID)
	input.OperationDate = strings.TrimSpace(input.OperationDate)
	return input
}

func NormalizeSettleMoneyDocumentInput(input SettleMoneyDocumentInput) SettleMoneyDocumentInput {
	input.AccountID = strings.TrimSpace(input.AccountID)
	input.OperationDate = strings.TrimSpace(input.OperationDate)
	input.Description = strings.TrimSpace(input.Description)
	return input
}

func ValidateCashAccountInput(input CreateCashAccountInput) error {
	if strings.TrimSpace(input.Name) == "" {
		return fmt.Errorf("%w: account name is required", ErrValidation)
	}
	switch input.AccountType {
	case "bank", "cash", "e_wallet", "card", "other":
	default:
		return fmt.Errorf("%w: account type is invalid", ErrValidation)
	}
	if input.CurrencyCode == "" || len(input.CurrencyCode) != 3 {
		return fmt.Errorf("%w: currency code must contain 3 letters", ErrValidation)
	}
	if input.OpeningBalance < 0 {
		return fmt.Errorf("%w: opening balance must be zero or greater", ErrValidation)
	}
	return nil
}

func ValidateMoneyOperationInput(input CreateMoneyOperationInput) error {
	if input.AccountID == "" {
		return fmt.Errorf("%w: account id is required", ErrValidation)
	}
	switch input.Direction {
	case "income", "expense", "transfer":
	default:
		return fmt.Errorf("%w: direction is invalid", ErrValidation)
	}
	if input.Amount <= 0 {
		return fmt.Errorf("%w: amount must be greater than zero", ErrValidation)
	}
	if input.Direction == "transfer" {
		if input.CounterpartyAccountID == "" {
			return fmt.Errorf("%w: counterparty account id is required for transfer", ErrValidation)
		}
		if input.CounterpartyAccountID == input.AccountID {
			return fmt.Errorf("%w: transfer accounts must be different", ErrValidation)
		}
	}
	if input.Direction != "transfer" && input.Category == "" {
		return fmt.Errorf("%w: category is required", ErrValidation)
	}
	if input.OperationDate != "" {
		if _, err := time.Parse("2006-01-02", input.OperationDate); err != nil {
			return fmt.Errorf("%w: operation date must be in YYYY-MM-DD format", ErrValidation)
		}
	}
	return nil
}

func ValidateSettleMoneyDocumentInput(input SettleMoneyDocumentInput) error {
	if input.AccountID == "" {
		return fmt.Errorf("%w: account id is required", ErrValidation)
	}
	if input.Amount <= 0 {
		return fmt.Errorf("%w: amount must be greater than zero", ErrValidation)
	}
	if input.OperationDate != "" {
		if _, err := time.Parse("2006-01-02", input.OperationDate); err != nil {
			return fmt.Errorf("%w: operation date must be in YYYY-MM-DD format", ErrValidation)
		}
	}
	return nil
}

func ValidateInventoryDocumentInput(input CreateInventoryDocumentInput) error {
	switch input.DocumentType {
	case "purchase_receipt", "write_off", "transfer", "sale_issue", "adjustment":
	default:
		return fmt.Errorf("%w: document type is invalid", ErrValidation)
	}
	if input.DocumentDate != "" {
		if _, err := time.Parse("2006-01-02", input.DocumentDate); err != nil {
			return fmt.Errorf("%w: document date must be in YYYY-MM-DD format", ErrValidation)
		}
	}
	if len(input.Lines) == 0 {
		return fmt.Errorf("%w: at least one line is required", ErrValidation)
	}
	if input.DocumentType == "transfer" && strings.TrimSpace(input.RelatedWarehouseName) == "" {
		return fmt.Errorf("%w: related warehouse name is required for transfer", ErrValidation)
	}
	if (input.DocumentType == "sale_issue" || input.DocumentType == "purchase_receipt") && strings.TrimSpace(input.ClientID) == "" {
		return fmt.Errorf("%w: client_id is required for sale and purchase documents", ErrValidation)
	}
	for index, line := range input.Lines {
		if strings.TrimSpace(line.ProductID) == "" && strings.TrimSpace(line.ServiceID) == "" {
			return fmt.Errorf("%w: lines[%d].product_id or service_id is required", ErrValidation, index)
		}
		if line.Quantity <= 0 {
			return fmt.Errorf("%w: lines[%d].quantity must be greater than zero", ErrValidation, index)
		}
		if line.UnitPrice < 0 {
			return fmt.Errorf("%w: lines[%d].unit_price must be zero or greater", ErrValidation, index)
		}
		if line.UnitCost < 0 {
			return fmt.Errorf("%w: lines[%d].unit_cost must be zero or greater", ErrValidation, index)
		}
	}
	return nil
}

func ValidateWarehouseInput(input CreateWarehouseInput) error {
	if strings.TrimSpace(input.Name) == "" {
		return fmt.Errorf("%w: warehouse name is required", ErrValidation)
	}
	return nil
}

// CompanyMembership describes one company the user belongs to, with the user's
// role inside it. It powers the multi-company switcher.
type CompanyMembership struct {
	ID        string `json:"id"`
	Name      string `json:"name"`
	Country   string `json:"country"`
	IIN       string `json:"iin,omitempty"`
	Role      string `json:"role"`
	IsDefault bool   `json:"is_default"`
}

type CreateCompanyInput struct {
	Name    string `json:"name"`
	Country string `json:"country"`
	IIN     string `json:"iin"`
}

type AddCompanyMemberInput struct {
	Phone string `json:"phone"`
	Role  string `json:"role"`
}

type UpdateCompanyMemberRoleInput struct {
	Role string `json:"role"`
}

type CompanyMember struct {
	UserID        string `json:"user_id"`
	FullName      string `json:"full_name"`
	Phone         string `json:"phone"`
	Role          string `json:"role"`
	RoleLabel     string `json:"role_label"`
	IsOwner       bool   `json:"is_owner"`
	IsCurrentUser bool   `json:"is_current_user"`
	JoinedAt      string `json:"joined_at"`
}

func NormalizeCompanyInput(input CreateCompanyInput) CreateCompanyInput {
	input.Name = strings.Join(strings.Fields(input.Name), " ")
	input.Country = strings.ToUpper(strings.TrimSpace(input.Country))
	input.IIN = strings.TrimSpace(input.IIN)
	return input
}

func ValidateCompanyInput(input CreateCompanyInput) error {
	if len([]rune(input.Name)) < 2 || len([]rune(input.Name)) > 160 {
		return fmt.Errorf("%w: company name must be between 2 and 160 characters", ErrValidation)
	}
	if len(input.Country) != 2 {
		return fmt.Errorf("%w: country must be a 2-letter code", ErrValidation)
	}
	if input.IIN != "" {
		if len(input.IIN) != 12 {
			return fmt.Errorf("%w: iin must contain exactly 12 digits", ErrValidation)
		}
		for _, symbol := range input.IIN {
			if symbol < '0' || symbol > '9' {
				return fmt.Errorf("%w: iin must contain only digits", ErrValidation)
			}
		}
	}
	if input.Country == "KZ" && input.IIN == "" {
		return fmt.Errorf("%w: iin is required for Kazakhstan companies", ErrValidation)
	}
	return nil
}

// CompanyDetail is the full company record returned for the editor screen.
type CompanyDetail struct {
	ID             string `json:"id"`
	Name           string `json:"name"`
	LegalForm      string `json:"legal_form,omitempty"`
	Country        string `json:"country"`
	IIN            string `json:"iin,omitempty"`
	RegistrationNo string `json:"registration_no,omitempty"`
	Email          string `json:"email,omitempty"`
	Phone          string `json:"phone,omitempty"`
	AddressLine    string `json:"address_line,omitempty"`
	City           string `json:"city,omitempty"`
	Region         string `json:"region,omitempty"`
	PostalCode     string `json:"postal_code,omitempty"`
	BankName       string `json:"bank_name,omitempty"`
	BankAccount    string `json:"bank_account,omitempty"`
	BankBik        string `json:"bank_bik,omitempty"`
	IsVatPayer     bool   `json:"is_vat_payer"`
	Role           string `json:"role"`
	IsDefault      bool   `json:"is_default"`
}

type UpdateCompanyInput struct {
	Name        string `json:"name"`
	LegalForm   string `json:"legal_form"`
	Country     string `json:"country"`
	IIN         string `json:"iin"`
	Email       string `json:"email"`
	Phone       string `json:"phone"`
	AddressLine string `json:"address_line"`
	City        string `json:"city"`
	Region      string `json:"region"`
	PostalCode  string `json:"postal_code"`
	BankName    string `json:"bank_name"`
	BankAccount string `json:"bank_account"`
	BankBik     string `json:"bank_bik"`
	IsVatPayer  bool   `json:"is_vat_payer"`
}

func NormalizeUpdateCompanyInput(input UpdateCompanyInput) UpdateCompanyInput {
	input.Name = strings.Join(strings.Fields(input.Name), " ")
	input.LegalForm = strings.TrimSpace(input.LegalForm)
	input.Country = strings.ToUpper(strings.TrimSpace(input.Country))
	input.IIN = strings.TrimSpace(input.IIN)
	input.Email = strings.TrimSpace(input.Email)
	input.Phone = strings.TrimSpace(input.Phone)
	input.AddressLine = strings.TrimSpace(input.AddressLine)
	input.City = strings.TrimSpace(input.City)
	input.Region = strings.TrimSpace(input.Region)
	input.PostalCode = strings.TrimSpace(input.PostalCode)
	input.BankName = strings.TrimSpace(input.BankName)
	input.BankAccount = strings.TrimSpace(input.BankAccount)
	input.BankBik = strings.TrimSpace(input.BankBik)
	return input
}

func ValidateUpdateCompanyInput(input UpdateCompanyInput) error {
	if len([]rune(input.Name)) < 2 || len([]rune(input.Name)) > 160 {
		return fmt.Errorf("%w: company name must be between 2 and 160 characters", ErrValidation)
	}
	if len(input.Country) != 2 {
		return fmt.Errorf("%w: country must be a 2-letter code", ErrValidation)
	}
	if input.IIN != "" {
		if len(input.IIN) != 12 {
			return fmt.Errorf("%w: iin must contain exactly 12 digits", ErrValidation)
		}
		for _, symbol := range input.IIN {
			if symbol < '0' || symbol > '9' {
				return fmt.Errorf("%w: iin must contain only digits", ErrValidation)
			}
		}
	}
	if input.Country == "KZ" && input.IIN == "" {
		return fmt.Errorf("%w: iin is required for Kazakhstan companies", ErrValidation)
	}
	return nil
}

var companyMemberRoles = map[string]bool{
	"admin": true, "manager": true, "accountant": true,
	"warehouse": true, "sales": true, "staff": true,
}

func NormalizeAddCompanyMemberInput(input AddCompanyMemberInput) AddCompanyMemberInput {
	input.Phone = normalizePhone(input.Phone)
	input.Role = strings.TrimSpace(strings.ToLower(input.Role))
	if input.Role == "" {
		input.Role = "staff"
	}
	return input
}

func ValidateAddCompanyMemberInput(input AddCompanyMemberInput) error {
	if strings.TrimSpace(input.Phone) == "" {
		return fmt.Errorf("%w: phone is required", ErrValidation)
	}
	if !companyMemberRoles[input.Role] {
		return fmt.Errorf("%w: role is invalid", ErrValidation)
	}
	return nil
}

func NormalizeUpdateCompanyMemberRoleInput(input UpdateCompanyMemberRoleInput) UpdateCompanyMemberRoleInput {
	input.Role = strings.TrimSpace(strings.ToLower(input.Role))
	return input
}

func ValidateUpdateCompanyMemberRoleInput(input UpdateCompanyMemberRoleInput) error {
	if input.Role == "owner" {
		return fmt.Errorf("%w: role is invalid", ErrValidation)
	}
	if !companyMemberRoles[input.Role] {
		return fmt.Errorf("%w: role is invalid", ErrValidation)
	}
	return nil
}

func companyRoleLabel(role string) string {
	switch strings.TrimSpace(strings.ToLower(role)) {
	case "owner":
		return "Владелец"
	case "admin":
		return "Администратор"
	case "manager":
		return "Менеджер"
	case "accountant":
		return "Бухгалтер"
	case "warehouse":
		return "Кладовщик"
	case "sales":
		return "Продажи"
	default:
		return "Сотрудник"
	}
}

func ValidateProductInput(input CreateProductInput) error {
	if strings.TrimSpace(input.Name) == "" {
		return fmt.Errorf("%w: product name is required", ErrValidation)
	}
	if strings.TrimSpace(input.SKU) == "" {
		return fmt.Errorf("%w: product sku is required", ErrValidation)
	}
	if strings.TrimSpace(input.UnitName) == "" {
		return fmt.Errorf("%w: unit name is required", ErrValidation)
	}
	switch input.ProductType {
	case "raw_material", "finished_product", "consumer_goods":
	default:
		return fmt.Errorf("%w: product type is invalid", ErrValidation)
	}
	if input.InitialQuantity < 0 {
		return fmt.Errorf("%w: initial quantity must be zero or greater", ErrValidation)
	}
	if input.MinQuantity < 0 {
		return fmt.Errorf("%w: min quantity must be zero or greater", ErrValidation)
	}
	if input.Price < 0 {
		return fmt.Errorf("%w: price must be zero or greater", ErrValidation)
	}
	if input.Cost < 0 {
		return fmt.Errorf("%w: cost must be zero or greater", ErrValidation)
	}
	if input.Barcode != "" && len(input.Barcode) < 8 {
		return fmt.Errorf("%w: barcode must contain at least 8 digits", ErrValidation)
	}
	return nil
}

func ValidateServiceInput(input CreateServiceInput) error {
	if strings.TrimSpace(input.Name) == "" {
		return fmt.Errorf("%w: service name is required", ErrValidation)
	}
	if input.Price < 0 {
		return fmt.Errorf("%w: price must be zero or greater", ErrValidation)
	}
	for i, m := range input.Materials {
		switch m.MaterialType {
		case "product", "sub_service", "external_service":
		default:
			return fmt.Errorf("%w: materials[%d].material_type is invalid", ErrValidation, i)
		}
		if m.MaterialType == "product" && strings.TrimSpace(m.ProductID) == "" {
			return fmt.Errorf("%w: materials[%d].product_id is required for product material", ErrValidation, i)
		}
		if m.MaterialType == "sub_service" && strings.TrimSpace(m.SubServiceID) == "" {
			return fmt.Errorf("%w: materials[%d].sub_service_id is required for sub_service material", ErrValidation, i)
		}
		if m.MaterialType == "external_service" && strings.TrimSpace(m.ExternalServiceName) == "" {
			return fmt.Errorf("%w: materials[%d].external_service_name is required", ErrValidation, i)
		}
		if m.Quantity <= 0 {
			return fmt.Errorf("%w: materials[%d].quantity must be greater than zero", ErrValidation, i)
		}
		if m.Cost < 0 {
			return fmt.Errorf("%w: materials[%d].cost must be zero or greater", ErrValidation, i)
		}
	}
	return nil
}

func NewProductFromInput(input CreateProductInput) Product {
	normalized := NormalizeProductInput(input)
	return Product{
		ID:            mustGenerateProductID(),
		Name:          normalized.Name,
		SKU:           normalized.SKU,
		Category:      normalized.Category,
		ProductType:   normalized.ProductType,
		UnitName:      normalized.UnitName,
		AllowedToSell: normalized.AllowedToSell,
		Quantity:      normalized.InitialQuantity,
		MinQuantity:   normalized.MinQuantity,
		Price:         normalized.Price,
		Cost:          normalized.Cost,
		Barcode:       normalized.Barcode,
		Status:        productStatus(normalized.InitialQuantity, normalized.MinQuantity),
		Movements:     []StockMovement{},
	}
}

func UpdatedProductFromInput(existing Product, input CreateProductInput) Product {
	normalized := NormalizeProductInput(input)
	existing.Name = normalized.Name
	existing.SKU = normalized.SKU
	existing.Category = normalized.Category
	existing.ProductType = normalized.ProductType
	existing.UnitName = normalized.UnitName
	existing.AllowedToSell = normalized.AllowedToSell
	existing.MinQuantity = normalized.MinQuantity
	existing.Price = normalized.Price
	existing.Cost = normalized.Cost
	existing.Barcode = normalized.Barcode
	existing.Status = productStatus(existing.Quantity, normalized.MinQuantity)
	return existing
}

func normalizeDigits(value string) string {
	return digitsOnly.ReplaceAllString(strings.TrimSpace(value), "")
}

func normalizePhone(value string) string {
	digits := normalizeDigits(value)
	if digits == "" {
		return ""
	}

	if strings.HasPrefix(digits, "8") && len(digits) == 11 {
		digits = "7" + digits[1:]
	}

	if !strings.HasPrefix(digits, "7") && len(digits) == 10 {
		digits = "7" + digits
	}

	return "+" + digits
}

func initialsOf(value string) string {
	normalized := strings.ReplaceAll(value, `"`, "")
	parts := strings.Fields(normalized)
	if len(parts) == 0 {
		return "MB"
	}

	initials := make([]string, 0, 2)
	for _, part := range parts {
		initials = append(initials, strings.ToUpper(string([]rune(part)[0])))
		if len(initials) == 2 {
			break
		}
	}

	return fmt.Sprintf("%s", strings.Join(initials, ""))
}

func mustGenerateClientID() string {
	id, err := generateClientID()
	if err != nil {
		return "00000000-0000-0000-0000-000000000000"
	}

	return id
}

func generateClientID() (string, error) {
	bytes := make([]byte, 16)
	if _, err := rand.Read(bytes); err != nil {
		return "", err
	}

	hexValue := hex.EncodeToString(bytes)
	return fmt.Sprintf(
		"%s-%s-%s-%s-%s",
		hexValue[0:8],
		hexValue[8:12],
		hexValue[12:16],
		hexValue[16:20],
		hexValue[20:32],
	), nil
}

func mustGenerateProductID() string {
	id, err := generateProductID()
	if err != nil {
		return "00000000-0000-0000-0000-000000000000"
	}

	return id
}

func mustGenerateAccountID() string {
	id, err := generateAccountID()
	if err != nil {
		return "00000000-0000-0000-0000-000000000000"
	}

	return id
}

func generateProductID() (string, error) {
	return generateAccountID()
}

func generateAccountID() (string, error) {
	bytes := make([]byte, 16)
	if _, err := rand.Read(bytes); err != nil {
		return "", err
	}

	hexValue := hex.EncodeToString(bytes)
	return fmt.Sprintf(
		"%s-%s-%s-%s-%s",
		hexValue[0:8],
		hexValue[8:12],
		hexValue[12:16],
		hexValue[16:20],
		hexValue[20:32],
	), nil
}

func productStatus(quantity int, minQuantity int) string {
	switch {
	case quantity <= 0:
		return "out_of_stock"
	case quantity <= minQuantity:
		return "low_stock"
	default:
		return "in_stock"
	}
}

// ── Production / Recipes ──────────────────────────────────────────────────────

type RecipeIngredient struct {
	ID          string  `json:"id"`
	ProductID   string  `json:"product_id"`
	ProductName string  `json:"product_name"`
	UnitName    string  `json:"unit_name"`
	Quantity    float64 `json:"quantity"`
}

type RecipeService struct {
	ID          string  `json:"id"`
	ServiceID   string  `json:"service_id"`
	ServiceName string  `json:"service_name"`
	Quantity    float64 `json:"quantity"`
}

type RecipeOutput struct {
	ID          string  `json:"id"`
	ProductID   string  `json:"product_id"`
	ProductName string  `json:"product_name"`
	UnitName    string  `json:"unit_name"`
	Quantity    float64 `json:"quantity"`
}

type Recipe struct {
	ID          string             `json:"id"`
	Name        string             `json:"name"`
	Description string             `json:"description"`
	Ingredients []RecipeIngredient `json:"ingredients"`
	Services    []RecipeService    `json:"services"`
	Outputs     []RecipeOutput     `json:"outputs"`
}

type CreateRecipeIngredientInput struct {
	ProductID string  `json:"product_id"`
	Quantity  float64 `json:"quantity"`
	UnitName  string  `json:"unit_name"`
}

type CreateRecipeServiceInput struct {
	ServiceID string  `json:"service_id"`
	Quantity  float64 `json:"quantity"`
}

type CreateRecipeOutputInput struct {
	ProductID string  `json:"product_id"`
	Quantity  float64 `json:"quantity"`
	UnitName  string  `json:"unit_name"`
}

type CreateRecipeInput struct {
	Name        string                        `json:"name"`
	Description string                        `json:"description"`
	Ingredients []CreateRecipeIngredientInput `json:"ingredients"`
	Services    []CreateRecipeServiceInput    `json:"services"`
	Outputs     []CreateRecipeOutputInput     `json:"outputs"`
}

type ProductionOrder struct {
	ID                  string  `json:"id"`
	DocumentNo          string  `json:"document_no"`
	RecipeID            string  `json:"recipe_id"`
	RecipeName          string  `json:"recipe_name"`
	SourceWarehouseID   string  `json:"source_warehouse_id"`
	SourceWarehouseName string  `json:"source_warehouse_name"`
	OutputWarehouseID   string  `json:"output_warehouse_id"`
	OutputWarehouseName string  `json:"output_warehouse_name"`
	BatchNumber         string  `json:"batch_number"`
	ResponsibleEmployee string  `json:"responsible_employee"`
	PlannedQuantity     float64 `json:"planned_quantity"`
	Status              string  `json:"status"`
	PlannedDate         string  `json:"planned_date"`
	Notes               string  `json:"notes"`
	CreatedAt           string  `json:"created_at"`
}

type CreateProductionOrderInput struct {
	DocumentNo          string  `json:"document_no"`
	RecipeID            string  `json:"recipe_id"`
	SourceWarehouseID   string  `json:"source_warehouse_id"`
	OutputWarehouseID   string  `json:"output_warehouse_id"`
	BatchNumber         string  `json:"batch_number"`
	ResponsibleEmployee string  `json:"responsible_employee"`
	PlannedQuantity     float64 `json:"planned_quantity"`
	PlannedDate         string  `json:"planned_date"`
	Notes               string  `json:"notes"`
}

type UpdateProductionOrderStatusInput struct {
	Status string `json:"status"`
}

func NormalizeRecipeInput(input CreateRecipeInput) CreateRecipeInput {
	input.Name = strings.TrimSpace(input.Name)
	input.Description = strings.TrimSpace(input.Description)
	for i := range input.Ingredients {
		input.Ingredients[i].ProductID = strings.TrimSpace(input.Ingredients[i].ProductID)
		input.Ingredients[i].UnitName = strings.TrimSpace(input.Ingredients[i].UnitName)
		if input.Ingredients[i].UnitName == "" {
			input.Ingredients[i].UnitName = "шт"
		}
		if input.Ingredients[i].Quantity <= 0 {
			input.Ingredients[i].Quantity = 1
		}
	}
	for i := range input.Services {
		input.Services[i].ServiceID = strings.TrimSpace(input.Services[i].ServiceID)
		if input.Services[i].Quantity <= 0 {
			input.Services[i].Quantity = 1
		}
	}
	for i := range input.Outputs {
		input.Outputs[i].ProductID = strings.TrimSpace(input.Outputs[i].ProductID)
		input.Outputs[i].UnitName = strings.TrimSpace(input.Outputs[i].UnitName)
		if input.Outputs[i].UnitName == "" {
			input.Outputs[i].UnitName = "шт"
		}
		if input.Outputs[i].Quantity <= 0 {
			input.Outputs[i].Quantity = 1
		}
	}
	return input
}

func ValidateRecipeInput(input CreateRecipeInput) error {
	if strings.TrimSpace(input.Name) == "" {
		return fmt.Errorf("%w: recipe name is required", ErrValidation)
	}
	if len(input.Outputs) == 0 {
		return fmt.Errorf("%w: at least one output product is required", ErrValidation)
	}
	for i, ing := range input.Ingredients {
		if strings.TrimSpace(ing.ProductID) == "" {
			return fmt.Errorf("%w: ingredients[%d].product_id is required", ErrValidation, i)
		}
		if ing.Quantity <= 0 {
			return fmt.Errorf("%w: ingredients[%d].quantity must be greater than zero", ErrValidation, i)
		}
	}
	for i, svc := range input.Services {
		if strings.TrimSpace(svc.ServiceID) == "" {
			return fmt.Errorf("%w: services[%d].service_id is required", ErrValidation, i)
		}
		if svc.Quantity <= 0 {
			return fmt.Errorf("%w: services[%d].quantity must be greater than zero", ErrValidation, i)
		}
	}
	for i, out := range input.Outputs {
		if strings.TrimSpace(out.ProductID) == "" {
			return fmt.Errorf("%w: outputs[%d].product_id is required", ErrValidation, i)
		}
		if out.Quantity <= 0 {
			return fmt.Errorf("%w: outputs[%d].quantity must be greater than zero", ErrValidation, i)
		}
	}
	return nil
}

func NormalizeProductionOrderInput(input CreateProductionOrderInput) CreateProductionOrderInput {
	input.DocumentNo = strings.TrimSpace(strings.ToUpper(input.DocumentNo))
	input.RecipeID = strings.TrimSpace(input.RecipeID)
	input.SourceWarehouseID = strings.TrimSpace(input.SourceWarehouseID)
	input.OutputWarehouseID = strings.TrimSpace(input.OutputWarehouseID)
	input.BatchNumber = strings.TrimSpace(input.BatchNumber)
	input.ResponsibleEmployee = strings.TrimSpace(input.ResponsibleEmployee)
	input.PlannedDate = strings.TrimSpace(input.PlannedDate)
	input.Notes = strings.TrimSpace(input.Notes)
	if input.PlannedQuantity <= 0 {
		input.PlannedQuantity = 1
	}
	return input
}

func ValidateProductionOrderInput(input CreateProductionOrderInput) error {
	if strings.TrimSpace(input.RecipeID) == "" {
		return fmt.Errorf("%w: recipe_id is required", ErrValidation)
	}
	if strings.TrimSpace(input.SourceWarehouseID) == "" {
		return fmt.Errorf("%w: source_warehouse_id is required", ErrValidation)
	}
	if strings.TrimSpace(input.OutputWarehouseID) == "" {
		return fmt.Errorf("%w: output_warehouse_id is required", ErrValidation)
	}
	if input.PlannedQuantity <= 0 {
		return fmt.Errorf("%w: planned_quantity must be greater than zero", ErrValidation)
	}
	if input.PlannedDate != "" {
		if _, err := time.Parse("2006-01-02", input.PlannedDate); err != nil {
			return fmt.Errorf("%w: planned_date must be in YYYY-MM-DD format", ErrValidation)
		}
	}
	return nil
}
