package business

import (
	"encoding/json"
	"errors"
	"log"
	"net/http"
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

	accessToken, err := extractBearerToken(r.Header.Get("Authorization"))
	if err != nil {
		response.Error(w, http.StatusUnauthorized, err.Error())
		return
	}

	user, err := h.authenticator.Authenticate(accessToken)
	if err != nil {
		if errors.Is(err, auth.ErrUnauthorized) {
			response.Error(w, http.StatusUnauthorized, err.Error())
			return
		}

		response.Error(w, http.StatusInternalServerError, "internal server error")
		return
	}

	clients, err := h.loadClients(user)
	if err != nil {
		log.Printf("business overview loadClients failed user=%s: %v", user.ID, err)
		response.Error(w, http.StatusInternalServerError, "internal server error")
		return
	}

	products, err := h.store.ListProducts(user)
	if err != nil {
		log.Printf("business overview ListProducts failed user=%s: %v", user.ID, err)
		response.Error(w, http.StatusInternalServerError, "internal server error")
		return
	}

	finance, err := h.store.GetFinance(user)
	if err != nil {
		log.Printf("business overview GetFinance failed user=%s: %v", user.ID, err)
		response.Error(w, http.StatusInternalServerError, "internal server error")
		return
	}

	response.JSON(w, http.StatusOK, buildOverview(user, clients, products, finance))
}

func (h Handler) Clients(w http.ResponseWriter, r *http.Request) {
	accessToken, err := extractBearerToken(r.Header.Get("Authorization"))
	if err != nil {
		response.Error(w, http.StatusUnauthorized, err.Error())
		return
	}

	user, err := h.authenticator.Authenticate(accessToken)
	if err != nil {
		if errors.Is(err, auth.ErrUnauthorized) {
			response.Error(w, http.StatusUnauthorized, err.Error())
			return
		}

		response.Error(w, http.StatusInternalServerError, "internal server error")
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
	accessToken, err := extractBearerToken(r.Header.Get("Authorization"))
	if err != nil {
		response.Error(w, http.StatusUnauthorized, err.Error())
		return
	}

	user, err := h.authenticator.Authenticate(accessToken)
	if err != nil {
		if errors.Is(err, auth.ErrUnauthorized) {
			response.Error(w, http.StatusUnauthorized, err.Error())
			return
		}

		response.Error(w, http.StatusInternalServerError, "internal server error")
		return
	}

	clientID := strings.TrimSpace(strings.TrimPrefix(r.URL.Path, "/api/v1/business/clients/"))
	if clientID == "" || strings.Contains(clientID, "/") {
		response.Error(w, http.StatusNotFound, "client not found")
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
	accessToken, err := extractBearerToken(r.Header.Get("Authorization"))
	if err != nil {
		response.Error(w, http.StatusUnauthorized, err.Error())
		return
	}

	user, err := h.authenticator.Authenticate(accessToken)
	if err != nil {
		if errors.Is(err, auth.ErrUnauthorized) {
			response.Error(w, http.StatusUnauthorized, err.Error())
			return
		}

		response.Error(w, http.StatusInternalServerError, "internal server error")
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

func (h Handler) ProductByID(w http.ResponseWriter, r *http.Request) {
	accessToken, err := extractBearerToken(r.Header.Get("Authorization"))
	if err != nil {
		response.Error(w, http.StatusUnauthorized, err.Error())
		return
	}

	user, err := h.authenticator.Authenticate(accessToken)
	if err != nil {
		if errors.Is(err, auth.ErrUnauthorized) {
			response.Error(w, http.StatusUnauthorized, err.Error())
			return
		}

		response.Error(w, http.StatusInternalServerError, "internal server error")
		return
	}

	productID := strings.TrimSpace(strings.TrimPrefix(r.URL.Path, "/api/v1/business/products/"))
	if productID == "" || strings.Contains(productID, "/") {
		response.Error(w, http.StatusNotFound, "product not found")
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
	accessToken, err := extractBearerToken(r.Header.Get("Authorization"))
	if err != nil {
		response.Error(w, http.StatusUnauthorized, err.Error())
		return
	}

	user, err := h.authenticator.Authenticate(accessToken)
	if err != nil {
		if errors.Is(err, auth.ErrUnauthorized) {
			response.Error(w, http.StatusUnauthorized, err.Error())
			return
		}

		response.Error(w, http.StatusInternalServerError, "internal server error")
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
	accessToken, err := extractBearerToken(r.Header.Get("Authorization"))
	if err != nil {
		response.Error(w, http.StatusUnauthorized, err.Error())
		return
	}

	user, err := h.authenticator.Authenticate(accessToken)
	if err != nil {
		if errors.Is(err, auth.ErrUnauthorized) {
			response.Error(w, http.StatusUnauthorized, err.Error())
			return
		}

		response.Error(w, http.StatusInternalServerError, "internal server error")
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
	accessToken, err := extractBearerToken(r.Header.Get("Authorization"))
	if err != nil {
		response.Error(w, http.StatusUnauthorized, err.Error())
		return
	}

	user, err := h.authenticator.Authenticate(accessToken)
	if err != nil {
		if errors.Is(err, auth.ErrUnauthorized) {
			response.Error(w, http.StatusUnauthorized, err.Error())
			return
		}

		response.Error(w, http.StatusInternalServerError, "internal server error")
		return
	}

	switch r.Method {
	case http.MethodGet:
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
	accessToken, err := extractBearerToken(r.Header.Get("Authorization"))
	if err != nil {
		response.Error(w, http.StatusUnauthorized, err.Error())
		return
	}

	user, err := h.authenticator.Authenticate(accessToken)
	if err != nil {
		if errors.Is(err, auth.ErrUnauthorized) {
			response.Error(w, http.StatusUnauthorized, err.Error())
			return
		}

		response.Error(w, http.StatusInternalServerError, "internal server error")
		return
	}

	if r.Method != http.MethodGet {
		response.Error(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}

	documentID := strings.TrimSpace(strings.TrimPrefix(r.URL.Path, "/api/v1/business/inventory-documents/"))
	if documentID == "" || strings.Contains(documentID, "/") {
		response.Error(w, http.StatusNotFound, "document not found")
		return
	}

	document, err := h.store.GetInventoryDocument(user, documentID)
	if err != nil {
		response.Error(w, http.StatusNotFound, "document not found")
		return
	}
	response.JSON(w, http.StatusOK, document)
}

func (h Handler) MoneyDocuments(w http.ResponseWriter, r *http.Request) {
	accessToken, err := extractBearerToken(r.Header.Get("Authorization"))
	if err != nil {
		response.Error(w, http.StatusUnauthorized, err.Error())
		return
	}

	user, err := h.authenticator.Authenticate(accessToken)
	if err != nil {
		if errors.Is(err, auth.ErrUnauthorized) {
			response.Error(w, http.StatusUnauthorized, err.Error())
			return
		}

		response.Error(w, http.StatusInternalServerError, "internal server error")
		return
	}

	if r.Method != http.MethodGet {
		response.Error(w, http.StatusMethodNotAllowed, "method not allowed")
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
	accessToken, err := extractBearerToken(r.Header.Get("Authorization"))
	if err != nil {
		response.Error(w, http.StatusUnauthorized, err.Error())
		return
	}

	user, err := h.authenticator.Authenticate(accessToken)
	if err != nil {
		if errors.Is(err, auth.ErrUnauthorized) {
			response.Error(w, http.StatusUnauthorized, err.Error())
			return
		}

		response.Error(w, http.StatusInternalServerError, "internal server error")
		return
	}

	if r.Method != http.MethodGet {
		response.Error(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}

	documentID := strings.TrimSpace(strings.TrimPrefix(r.URL.Path, "/api/v1/business/money-documents/"))
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
