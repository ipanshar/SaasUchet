package auth

import "time"

type User struct {
	ID        string    `json:"id"`
	FullName  string    `json:"full_name"`
	Phone     string    `json:"phone"`
	CreatedAt time.Time `json:"created_at"`
}

type AuthResult struct {
	AccessToken string    `json:"access_token"`
	TokenType   string    `json:"token_type"`
	ExpiresAt   time.Time `json:"expires_at"`
	User        User      `json:"user"`
}

type userRecord struct {
	User
	PasswordHash string
}

type session struct {
	Token     string
	UserID    string
	CreatedAt time.Time
	ExpiresAt time.Time
}
