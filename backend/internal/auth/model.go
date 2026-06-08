package auth

import "time"

type Company struct {
	Name    string `json:"name"`
	Country string `json:"country"`
	IIN     string `json:"iin,omitempty"`
}

type User struct {
	ID        string    `json:"id"`
	FullName  string    `json:"full_name"`
	Phone     string    `json:"phone"`
	Companies []Company `json:"companies"`
	CreatedAt time.Time `json:"created_at"`

	// ActiveCompanyID is resolved per-request from the X-Company-Id header.
	// It is never persisted nor serialized.
	ActiveCompanyID string `json:"-"`
}

type UserDeletionBlocker struct {
	HasOwnedCompanies  bool
	HasBusinessHistory bool
	Message            string
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
