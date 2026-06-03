package business

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/altyncloud/saas-uchet/backend/internal/auth"
)

type stubAuthenticator struct {
	user auth.User
	err  error
}

func (s stubAuthenticator) Authenticate(accessToken string) (auth.User, error) {
	return s.user, s.err
}

func TestHandlerCreatesAndListsClients(t *testing.T) {
	store := NewMemoryStore()
	handler := NewHandler(
		stubAuthenticator{
			user: auth.User{
				ID:       "usr_1",
				FullName: "Иван Петров",
				Phone:    "+77011234567",
			},
		},
		store,
	)

	payload, err := json.Marshal(CreateClientInput{
		Name:    "ТОО Altyn Trade",
		Contact: "Азамат Нурланов",
		Phone:   "8 777 123 45 67",
		Email:   "sales@altyn.kz",
		Segment: "VIP",
		BIN:     "123456789012",
	})
	if err != nil {
		t.Fatalf("marshal payload: %v", err)
	}

	createRequest := httptest.NewRequest(http.MethodPost, "/api/v1/business/clients", bytes.NewReader(payload))
	createRequest.Header.Set("Authorization", "Bearer token")
	createRecorder := httptest.NewRecorder()

	handler.Clients(createRecorder, createRequest)

	if createRecorder.Code != http.StatusCreated {
		t.Fatalf("unexpected create status: %d body=%s", createRecorder.Code, createRecorder.Body.String())
	}

	var created Client
	if err := json.Unmarshal(createRecorder.Body.Bytes(), &created); err != nil {
		t.Fatalf("decode created client: %v", err)
	}

	if created.Name != "ТОО Altyn Trade" {
		t.Fatalf("unexpected client name: %s", created.Name)
	}
	if created.ID == "" {
		t.Fatalf("expected created client id")
	}

	if created.Phone != "+77771234567" {
		t.Fatalf("unexpected normalized phone: %s", created.Phone)
	}

	listRequest := httptest.NewRequest(http.MethodGet, "/api/v1/business/clients", nil)
	listRequest.Header.Set("Authorization", "Bearer token")
	listRecorder := httptest.NewRecorder()

	handler.Clients(listRecorder, listRequest)

	if listRecorder.Code != http.StatusOK {
		t.Fatalf("unexpected list status: %d body=%s", listRecorder.Code, listRecorder.Body.String())
	}

	var response struct {
		Clients []Client `json:"clients"`
	}
	if err := json.Unmarshal(listRecorder.Body.Bytes(), &response); err != nil {
		t.Fatalf("decode clients response: %v", err)
	}

	if len(response.Clients) != 1 {
		t.Fatalf("unexpected client count: %d", len(response.Clients))
	}
}

func TestHandlerUpdatesAndDeletesClient(t *testing.T) {
	store := NewMemoryStore()
	handler := NewHandler(
		stubAuthenticator{
			user: auth.User{
				ID:       "usr_1",
				FullName: "Иван Петров",
				Phone:    "+77011234567",
			},
		},
		store,
	)

	createPayload, err := json.Marshal(CreateClientInput{
		Name:    "ТОО Original",
		Contact: "Первый Контакт",
		Phone:   "+7 777 111 22 33",
		Email:   "original@crm.kz",
		Segment: "Regular",
		BIN:     "111111111111",
	})
	if err != nil {
		t.Fatalf("marshal create payload: %v", err)
	}

	createRequest := httptest.NewRequest(http.MethodPost, "/api/v1/business/clients", bytes.NewReader(createPayload))
	createRequest.Header.Set("Authorization", "Bearer token")
	createRecorder := httptest.NewRecorder()
	handler.Clients(createRecorder, createRequest)

	var created Client
	if err := json.Unmarshal(createRecorder.Body.Bytes(), &created); err != nil {
		t.Fatalf("decode created client: %v", err)
	}

	updatePayload, err := json.Marshal(CreateClientInput{
		Name:    "ТОО Updated",
		Contact: "Новый Контакт",
		Phone:   "+7 701 555 44 33",
		Email:   "updated@crm.kz",
		Segment: "VIP",
		BIN:     "999999999999",
	})
	if err != nil {
		t.Fatalf("marshal update payload: %v", err)
	}

	updateRequest := httptest.NewRequest(
		http.MethodPut,
		"/api/v1/business/clients/"+created.ID,
		bytes.NewReader(updatePayload),
	)
	updateRequest.Header.Set("Authorization", "Bearer token")
	updateRecorder := httptest.NewRecorder()
	handler.ClientByID(updateRecorder, updateRequest)

	if updateRecorder.Code != http.StatusOK {
		t.Fatalf("unexpected update status: %d body=%s", updateRecorder.Code, updateRecorder.Body.String())
	}

	var updated Client
	if err := json.Unmarshal(updateRecorder.Body.Bytes(), &updated); err != nil {
		t.Fatalf("decode updated client: %v", err)
	}
	if updated.Name != "ТОО Updated" {
		t.Fatalf("unexpected updated name: %s", updated.Name)
	}

	deleteRequest := httptest.NewRequest(
		http.MethodDelete,
		"/api/v1/business/clients/"+created.ID,
		nil,
	)
	deleteRequest.Header.Set("Authorization", "Bearer token")
	deleteRecorder := httptest.NewRecorder()
	handler.ClientByID(deleteRecorder, deleteRequest)

	if deleteRecorder.Code != http.StatusNoContent {
		t.Fatalf("unexpected delete status: %d body=%s", deleteRecorder.Code, deleteRecorder.Body.String())
	}

	listRequest := httptest.NewRequest(http.MethodGet, "/api/v1/business/clients", nil)
	listRequest.Header.Set("Authorization", "Bearer token")
	listRecorder := httptest.NewRecorder()
	handler.Clients(listRecorder, listRequest)

	var listResponse struct {
		Clients []Client `json:"clients"`
	}
	if err := json.Unmarshal(listRecorder.Body.Bytes(), &listResponse); err != nil {
		t.Fatalf("decode clients after delete: %v", err)
	}
	if len(listResponse.Clients) != 0 {
		t.Fatalf("expected 0 clients after delete, got %d", len(listResponse.Clients))
	}
}

func TestHandlerCreatesUpdatesAndDeletesProduct(t *testing.T) {
	store := NewMemoryStore()
	handler := NewHandler(
		stubAuthenticator{
			user: auth.User{
				ID:       "usr_1",
				FullName: "Иван Петров",
				Phone:    "+77011234567",
			},
		},
		store,
	)

	createPayload, err := json.Marshal(CreateProductInput{
		Name:            "Ноутбук Lenovo ThinkPad",
		SKU:             "TECH-001",
		Category:        "Техника",
		InitialQuantity: 15,
		MinQuantity:     10,
		Price:           350000,
		Cost:            280000,
		Barcode:         "8600123456789",
	})
	if err != nil {
		t.Fatalf("marshal create product payload: %v", err)
	}

	createRequest := httptest.NewRequest(http.MethodPost, "/api/v1/business/products", bytes.NewReader(createPayload))
	createRequest.Header.Set("Authorization", "Bearer token")
	createRecorder := httptest.NewRecorder()
	handler.Products(createRecorder, createRequest)

	if createRecorder.Code != http.StatusCreated {
		t.Fatalf("unexpected create product status: %d body=%s", createRecorder.Code, createRecorder.Body.String())
	}

	var created Product
	if err := json.Unmarshal(createRecorder.Body.Bytes(), &created); err != nil {
		t.Fatalf("decode created product: %v", err)
	}
	if created.ID == "" {
		t.Fatalf("expected product id")
	}
	if created.Status != "in_stock" {
		t.Fatalf("unexpected product status: %s", created.Status)
	}

	listRequest := httptest.NewRequest(http.MethodGet, "/api/v1/business/products", nil)
	listRequest.Header.Set("Authorization", "Bearer token")
	listRecorder := httptest.NewRecorder()
	handler.Products(listRecorder, listRequest)

	var listResponse struct {
		Products []Product `json:"products"`
	}
	if err := json.Unmarshal(listRecorder.Body.Bytes(), &listResponse); err != nil {
		t.Fatalf("decode products response: %v", err)
	}
	if len(listResponse.Products) != 1 {
		t.Fatalf("expected 1 product, got %d", len(listResponse.Products))
	}

	updatePayload, err := json.Marshal(CreateProductInput{
		Name:            "Ноутбук Lenovo ThinkPad Gen 2",
		SKU:             "TECH-001",
		Category:        "Техника",
		InitialQuantity: 0,
		MinQuantity:     20,
		Price:           360000,
		Cost:            285000,
		Barcode:         "8600123456789",
	})
	if err != nil {
		t.Fatalf("marshal update product payload: %v", err)
	}

	updateRequest := httptest.NewRequest(
		http.MethodPut,
		"/api/v1/business/products/"+created.ID,
		bytes.NewReader(updatePayload),
	)
	updateRequest.Header.Set("Authorization", "Bearer token")
	updateRecorder := httptest.NewRecorder()
	handler.ProductByID(updateRecorder, updateRequest)

	if updateRecorder.Code != http.StatusOK {
		t.Fatalf("unexpected update product status: %d body=%s", updateRecorder.Code, updateRecorder.Body.String())
	}

	var updated Product
	if err := json.Unmarshal(updateRecorder.Body.Bytes(), &updated); err != nil {
		t.Fatalf("decode updated product: %v", err)
	}
	if updated.Name != "Ноутбук Lenovo ThinkPad Gen 2" {
		t.Fatalf("unexpected updated product name: %s", updated.Name)
	}
	if updated.MinQuantity != 20 {
		t.Fatalf("unexpected updated min quantity: %d", updated.MinQuantity)
	}

	deleteRequest := httptest.NewRequest(
		http.MethodDelete,
		"/api/v1/business/products/"+created.ID,
		nil,
	)
	deleteRequest.Header.Set("Authorization", "Bearer token")
	deleteRecorder := httptest.NewRecorder()
	handler.ProductByID(deleteRecorder, deleteRequest)

	if deleteRecorder.Code != http.StatusNoContent {
		t.Fatalf("unexpected delete product status: %d body=%s", deleteRecorder.Code, deleteRecorder.Body.String())
	}
}

func TestHandlerCreatesAndListsCashAccount(t *testing.T) {
	store := NewMemoryStore()
	handler := NewHandler(
		stubAuthenticator{
			user: auth.User{
				ID:       "usr_1",
				FullName: "Иван Петров",
				Phone:    "+77011234567",
			},
		},
		store,
	)

	createPayload, err := json.Marshal(CreateCashAccountInput{
		Name:           "Kaspi Bank",
		AccountType:    "bank",
		CurrencyCode:   "KZT",
		BankName:       "Kaspi",
		IBAN:           "KZ123456789012345678",
		BIK:            "CASPKZKA",
		OpeningBalance: 2500000,
	})
	if err != nil {
		t.Fatalf("marshal create account payload: %v", err)
	}

	createRequest := httptest.NewRequest(http.MethodPost, "/api/v1/business/accounts", bytes.NewReader(createPayload))
	createRequest.Header.Set("Authorization", "Bearer token")
	createRecorder := httptest.NewRecorder()
	handler.Accounts(createRecorder, createRequest)

	if createRecorder.Code != http.StatusCreated {
		t.Fatalf("unexpected create account status: %d body=%s", createRecorder.Code, createRecorder.Body.String())
	}

	var created BankAccount
	if err := json.Unmarshal(createRecorder.Body.Bytes(), &created); err != nil {
		t.Fatalf("decode created account: %v", err)
	}
	if created.Name != "Kaspi Bank" {
		t.Fatalf("unexpected account name: %s", created.Name)
	}
	if created.Balance != 2500000 {
		t.Fatalf("unexpected account balance: %d", created.Balance)
	}

	listRequest := httptest.NewRequest(http.MethodGet, "/api/v1/business/accounts", nil)
	listRequest.Header.Set("Authorization", "Bearer token")
	listRecorder := httptest.NewRecorder()
	handler.Accounts(listRecorder, listRequest)

	if listRecorder.Code != http.StatusOK {
		t.Fatalf("unexpected list account status: %d body=%s", listRecorder.Code, listRecorder.Body.String())
	}

	var response struct {
		Accounts []BankAccount `json:"accounts"`
		Summary  struct {
			TotalBalance int `json:"total_balance"`
		} `json:"summary"`
	}
	if err := json.Unmarshal(listRecorder.Body.Bytes(), &response); err != nil {
		t.Fatalf("decode account list: %v", err)
	}
	if len(response.Accounts) != 1 {
		t.Fatalf("expected 1 account, got %d", len(response.Accounts))
	}
	if response.Summary.TotalBalance != 2500000 {
		t.Fatalf("unexpected summary balance: %d", response.Summary.TotalBalance)
	}
}

func TestHandlerCreatesMoneyOperations(t *testing.T) {
	store := NewMemoryStore()
	handler := NewHandler(
		stubAuthenticator{
			user: auth.User{
				ID:       "usr_1",
				FullName: "Иван Петров",
				Phone:    "+77011234567",
			},
		},
		store,
	)

	createPrimaryPayload, err := json.Marshal(CreateCashAccountInput{
		Name:           "Kaspi Bank",
		AccountType:    "bank",
		CurrencyCode:   "KZT",
		OpeningBalance: 1000000,
	})
	if err != nil {
		t.Fatalf("marshal primary account payload: %v", err)
	}

	primaryRequest := httptest.NewRequest(http.MethodPost, "/api/v1/business/accounts", bytes.NewReader(createPrimaryPayload))
	primaryRequest.Header.Set("Authorization", "Bearer token")
	primaryRecorder := httptest.NewRecorder()
	handler.Accounts(primaryRecorder, primaryRequest)
	if primaryRecorder.Code != http.StatusCreated {
		t.Fatalf("unexpected primary account status: %d body=%s", primaryRecorder.Code, primaryRecorder.Body.String())
	}

	var primaryAccount BankAccount
	if err := json.Unmarshal(primaryRecorder.Body.Bytes(), &primaryAccount); err != nil {
		t.Fatalf("decode primary account: %v", err)
	}

	createSecondaryPayload, err := json.Marshal(CreateCashAccountInput{
		Name:           "Касса",
		AccountType:    "cash",
		CurrencyCode:   "KZT",
		OpeningBalance: 0,
	})
	if err != nil {
		t.Fatalf("marshal secondary account payload: %v", err)
	}

	secondaryRequest := httptest.NewRequest(http.MethodPost, "/api/v1/business/accounts", bytes.NewReader(createSecondaryPayload))
	secondaryRequest.Header.Set("Authorization", "Bearer token")
	secondaryRecorder := httptest.NewRecorder()
	handler.Accounts(secondaryRecorder, secondaryRequest)
	if secondaryRecorder.Code != http.StatusCreated {
		t.Fatalf("unexpected secondary account status: %d body=%s", secondaryRecorder.Code, secondaryRecorder.Body.String())
	}

	var secondaryAccount BankAccount
	if err := json.Unmarshal(secondaryRecorder.Body.Bytes(), &secondaryAccount); err != nil {
		t.Fatalf("decode secondary account: %v", err)
	}

	moneyOperations := []CreateMoneyOperationInput{
		{
			AccountID:   primaryAccount.ID,
			Direction:   "income",
			Amount:      300000,
			Category:    "Продажи",
			Description: "Оплата клиента",
		},
		{
			AccountID:   primaryAccount.ID,
			Direction:   "expense",
			Amount:      120000,
			Category:    "Аренда",
			Description: "Аренда офиса",
		},
		{
			AccountID:             primaryAccount.ID,
			CounterpartyAccountID: secondaryAccount.ID,
			Direction:             "transfer",
			Amount:                50000,
			Description:           "Перемещение в кассу",
		},
	}

	for _, operation := range moneyOperations {
		payload, err := json.Marshal(operation)
		if err != nil {
			t.Fatalf("marshal money operation payload: %v", err)
		}

		request := httptest.NewRequest(http.MethodPost, "/api/v1/business/money-operations", bytes.NewReader(payload))
		request.Header.Set("Authorization", "Bearer token")
		recorder := httptest.NewRecorder()
		handler.MoneyOperations(recorder, request)

		if recorder.Code != http.StatusCreated {
			t.Fatalf("unexpected money operation status: %d body=%s", recorder.Code, recorder.Body.String())
		}
	}

	listRequest := httptest.NewRequest(http.MethodGet, "/api/v1/business/accounts", nil)
	listRequest.Header.Set("Authorization", "Bearer token")
	listRecorder := httptest.NewRecorder()
	handler.Accounts(listRecorder, listRequest)

	if listRecorder.Code != http.StatusOK {
		t.Fatalf("unexpected accounts status: %d body=%s", listRecorder.Code, listRecorder.Body.String())
	}

	var response struct {
		Accounts []BankAccount `json:"accounts"`
		Summary  struct {
			TotalBalance int `json:"total_balance"`
			Income       int `json:"income"`
			Expense      int `json:"expense"`
		} `json:"summary"`
	}
	if err := json.Unmarshal(listRecorder.Body.Bytes(), &response); err != nil {
		t.Fatalf("decode account response: %v", err)
	}

	if len(response.Accounts) != 2 {
		t.Fatalf("expected 2 accounts, got %d", len(response.Accounts))
	}
	if response.Summary.TotalBalance != 1180000 {
		t.Fatalf("unexpected total balance: %d", response.Summary.TotalBalance)
	}
	if response.Summary.Income != 350000 {
		t.Fatalf("unexpected income summary: %d", response.Summary.Income)
	}
	if response.Summary.Expense != 170000 {
		t.Fatalf("unexpected expense summary: %d", response.Summary.Expense)
	}
}

func TestHandlerListsDocumentFeeds(t *testing.T) {
	store := NewMemoryStore()
	handler := NewHandler(
		stubAuthenticator{
			user: auth.User{
				ID:       "usr_1",
				FullName: "Иван Петров",
				Phone:    "+77011234567",
			},
		},
		store,
	)

	productPayload, _ := json.Marshal(CreateProductInput{
		Name:            "Тестовый товар",
		SKU:             "DOC-001",
		Category:        "Тест",
		InitialQuantity: 10,
		MinQuantity:     2,
		Price:           10000,
		Cost:            7000,
		Barcode:         "12345678",
	})
	productRequest := httptest.NewRequest(http.MethodPost, "/api/v1/business/products", bytes.NewReader(productPayload))
	productRequest.Header.Set("Authorization", "Bearer token")
	productRecorder := httptest.NewRecorder()
	handler.Products(productRecorder, productRequest)

	accountPayload, _ := json.Marshal(CreateCashAccountInput{
		Name:           "Основной счет",
		AccountType:    "bank",
		CurrencyCode:   "KZT",
		OpeningBalance: 500000,
	})
	accountRequest := httptest.NewRequest(http.MethodPost, "/api/v1/business/accounts", bytes.NewReader(accountPayload))
	accountRequest.Header.Set("Authorization", "Bearer token")
	accountRecorder := httptest.NewRecorder()
	handler.Accounts(accountRecorder, accountRequest)

	var account BankAccount
	if err := json.Unmarshal(accountRecorder.Body.Bytes(), &account); err != nil {
		t.Fatalf("decode account: %v", err)
	}

	operationPayload, _ := json.Marshal(CreateMoneyOperationInput{
		AccountID:   account.ID,
		Direction:   "income",
		Amount:      100000,
		Category:    "Продажи",
		Description: "Оплата клиента",
	})
	operationRequest := httptest.NewRequest(http.MethodPost, "/api/v1/business/money-operations", bytes.NewReader(operationPayload))
	operationRequest.Header.Set("Authorization", "Bearer token")
	operationRecorder := httptest.NewRecorder()
	handler.MoneyOperations(operationRecorder, operationRequest)

	inventoryRequest := httptest.NewRequest(http.MethodGet, "/api/v1/business/inventory-documents", nil)
	inventoryRequest.Header.Set("Authorization", "Bearer token")
	inventoryRecorder := httptest.NewRecorder()
	handler.InventoryDocuments(inventoryRecorder, inventoryRequest)
	if inventoryRecorder.Code != http.StatusOK {
		t.Fatalf("unexpected inventory documents status: %d body=%s", inventoryRecorder.Code, inventoryRecorder.Body.String())
	}

	moneyRequest := httptest.NewRequest(http.MethodGet, "/api/v1/business/money-documents", nil)
	moneyRequest.Header.Set("Authorization", "Bearer token")
	moneyRecorder := httptest.NewRecorder()
	handler.MoneyDocuments(moneyRecorder, moneyRequest)
	if moneyRecorder.Code != http.StatusOK {
		t.Fatalf("unexpected money documents status: %d body=%s", moneyRecorder.Code, moneyRecorder.Body.String())
	}
}
