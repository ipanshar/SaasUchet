package auth

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestHandlerDeleteProfileReturnsValidationErrorForBlockedUser(t *testing.T) {
	store := NewMemoryStore()
	store.deletionBlocker = &UserDeletionBlocker{
		HasOwnedCompanies: true,
		Message:           "Нельзя удалить аккаунт, пока у вас есть собственные компании. Сначала передайте владение или архивируйте компанию.",
	}
	service := NewService(store, 24*time.Hour)
	handler := NewHandler(service)

	registerResult, err := service.Register(RegisterInput{
		FullName: "Иван Петров",
		Phone:    "+77011234567",
		Password: "StrongPass123",
	})
	if err != nil {
		t.Fatalf("register returned error: %v", err)
	}

	request := httptest.NewRequest(http.MethodDelete, "/api/v1/profile", nil)
	request.Header.Set("Authorization", "Bearer "+registerResult.AccessToken)
	recorder := httptest.NewRecorder()

	handler.DeleteProfile(recorder, request)

	if recorder.Code != http.StatusBadRequest {
		t.Fatalf("expected status 400, got %d", recorder.Code)
	}

	var body map[string]string
	if err := json.Unmarshal(recorder.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode response body: %v", err)
	}

	if body["error"] != store.deletionBlocker.Message {
		t.Fatalf("unexpected error message: %q", body["error"])
	}
}
