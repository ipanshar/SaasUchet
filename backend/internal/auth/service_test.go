package auth

import (
	"errors"
	"testing"
	"time"
)

func TestServiceRegisterAndAuthenticate(t *testing.T) {
	store := NewMemoryStore()
	service := NewService(store, 24*time.Hour)
	now := time.Date(2026, 5, 29, 8, 0, 0, 0, time.UTC)
	service.now = func() time.Time { return now }

	result, err := service.Register(RegisterInput{
		FullName: "Иван Петров",
		Phone:    "+7 (701) 123-45-67",
		Password: "StrongPass123",
	})
	if err != nil {
		t.Fatalf("register returned error: %v", err)
	}

	if result.User.FullName != "Иван Петров" {
		t.Fatalf("unexpected full name: %s", result.User.FullName)
	}

	if result.User.Phone != "+77011234567" {
		t.Fatalf("unexpected phone: %s", result.User.Phone)
	}

	if result.TokenType != "Bearer" {
		t.Fatalf("unexpected token type: %s", result.TokenType)
	}

	if result.ExpiresAt != now.Add(24*time.Hour) {
		t.Fatalf("unexpected expiration: %s", result.ExpiresAt)
	}

	user, err := service.Authenticate(result.AccessToken)
	if err != nil {
		t.Fatalf("authenticate returned error: %v", err)
	}

	if user.ID != result.User.ID {
		t.Fatalf("unexpected user id: %s", user.ID)
	}
}

func TestServiceRejectsDuplicatePhone(t *testing.T) {
	store := NewMemoryStore()
	service := NewService(store, 24*time.Hour)

	_, err := service.Register(RegisterInput{
		FullName: "Иван Петров",
		Phone:    "+77011234567",
		Password: "StrongPass123",
	})
	if err != nil {
		t.Fatalf("first register returned error: %v", err)
	}

	_, err = service.Register(RegisterInput{
		FullName: "Иван Петров",
		Phone:    "8 701 123 45 67",
		Password: "StrongPass123",
	})
	if !errors.Is(err, ErrPhoneTaken) {
		t.Fatalf("expected ErrPhoneTaken, got: %v", err)
	}
}

func TestServiceLoginRejectsWrongPassword(t *testing.T) {
	store := NewMemoryStore()
	service := NewService(store, 24*time.Hour)

	_, err := service.Register(RegisterInput{
		FullName: "Иван Петров",
		Phone:    "+77011234567",
		Password: "StrongPass123",
	})
	if err != nil {
		t.Fatalf("register returned error: %v", err)
	}

	_, err = service.Login(LoginInput{
		Phone:    "+77011234567",
		Password: "WrongPass123",
	})
	if !errors.Is(err, ErrInvalidCredentials) {
		t.Fatalf("expected ErrInvalidCredentials, got: %v", err)
	}
}

func TestServiceUpdateProfileChangesNamePhoneAndPassword(t *testing.T) {
	store := NewMemoryStore()
	service := NewService(store, 24*time.Hour)
	now := time.Date(2026, 5, 29, 8, 0, 0, 0, time.UTC)
	service.now = func() time.Time { return now }

	registerResult, err := service.Register(RegisterInput{
		FullName: "Иван Петров",
		Phone:    "+77011234567",
		Password: "StrongPass123",
	})
	if err != nil {
		t.Fatalf("register returned error: %v", err)
	}

	updatedUser, err := service.UpdateProfile(registerResult.AccessToken, UpdateProfileInput{
		FullName: "Иван Сергеевич Петров",
		Phone:    "8 777 111 22 33",
		Password: "NewStrongPass123",
	})
	if err != nil {
		t.Fatalf("update profile returned error: %v", err)
	}

	if updatedUser.FullName != "Иван Сергеевич Петров" {
		t.Fatalf("unexpected full name after update: %s", updatedUser.FullName)
	}

	if updatedUser.Phone != "+77771112233" {
		t.Fatalf("unexpected phone after update: %s", updatedUser.Phone)
	}

	loginResult, err := service.Login(LoginInput{
		Phone:    "+77771112233",
		Password: "NewStrongPass123",
	})
	if err != nil {
		t.Fatalf("login with updated credentials returned error: %v", err)
	}

	if loginResult.User.ID != registerResult.User.ID {
		t.Fatalf("unexpected user id after login: %s", loginResult.User.ID)
	}
}

func TestServiceDeleteProfileRevokesAccess(t *testing.T) {
	store := NewMemoryStore()
	service := NewService(store, 24*time.Hour)

	registerResult, err := service.Register(RegisterInput{
		FullName: "Иван Петров",
		Phone:    "+77011234567",
		Password: "StrongPass123",
	})
	if err != nil {
		t.Fatalf("register returned error: %v", err)
	}

	if err := service.DeleteProfile(registerResult.AccessToken); err != nil {
		t.Fatalf("delete profile returned error: %v", err)
	}

	_, err = service.Authenticate(registerResult.AccessToken)
	if !errors.Is(err, ErrUnauthorized) {
		t.Fatalf("expected ErrUnauthorized after delete, got: %v", err)
	}
}
