package business

import (
	"encoding/json"
	"errors"
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

	clients, err := h.loadClients(user.ID)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "internal server error")
		return
	}

	response.JSON(w, http.StatusOK, buildOverview(user, clients))
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

func (h Handler) listClients(w http.ResponseWriter, user auth.User) {
	clients, err := h.loadClients(user.ID)
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

	clients, err := h.loadClients(user.ID)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "internal server error")
		return
	}

	client := NewClientFromInput(input)
	clients = append([]Client{client}, clients...)

	if err := h.store.SaveClients(user.ID, clients); err != nil {
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

	clients, err := h.loadClients(user.ID)
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
	if err := h.store.SaveClients(user.ID, clients); err != nil {
		response.Error(w, http.StatusInternalServerError, "internal server error")
		return
	}

	response.JSON(w, http.StatusOK, clients[index])
}

func (h Handler) deleteClient(w http.ResponseWriter, user auth.User, clientID string) {
	clients, err := h.loadClients(user.ID)
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
	if err := h.store.SaveClients(user.ID, clients); err != nil {
		response.Error(w, http.StatusInternalServerError, "internal server error")
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

func (h Handler) loadClients(userID string) ([]Client, error) {
	clients, err := h.store.ListClients(userID)
	if err != nil {
		return nil, err
	}

	if len(clients) > 0 {
		return clients, nil
	}

	seedClients := defaultClients()
	if err := h.store.SaveClients(userID, seedClients); err != nil {
		return nil, err
	}

	return seedClients, nil
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
