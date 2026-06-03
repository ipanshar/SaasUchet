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

	if len(response.Clients) != 5 {
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

	listRequest := httptest.NewRequest(http.MethodGet, "/api/v1/business/clients", nil)
	listRequest.Header.Set("Authorization", "Bearer token")
	listRecorder := httptest.NewRecorder()
	handler.Clients(listRecorder, listRequest)

	var listResponse struct {
		Clients []Client `json:"clients"`
	}
	if err := json.Unmarshal(listRecorder.Body.Bytes(), &listResponse); err != nil {
		t.Fatalf("decode seeded clients: %v", err)
	}
	if len(listResponse.Clients) == 0 {
		t.Fatalf("expected seeded clients")
	}

	targetClient := listResponse.Clients[0]
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
		"/api/v1/business/clients/"+targetClient.ID,
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
		"/api/v1/business/clients/"+targetClient.ID,
		nil,
	)
	deleteRequest.Header.Set("Authorization", "Bearer token")
	deleteRecorder := httptest.NewRecorder()
	handler.ClientByID(deleteRecorder, deleteRequest)

	if deleteRecorder.Code != http.StatusNoContent {
		t.Fatalf("unexpected delete status: %d body=%s", deleteRecorder.Code, deleteRecorder.Body.String())
	}
}
