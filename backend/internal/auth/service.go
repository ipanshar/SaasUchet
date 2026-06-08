package auth

import (
	"encoding/base64"
	"encoding/hex"
	"fmt"
	"strings"
	"time"
)

type RegisterInput struct {
	FullName string
	Phone    string
	Password string
}

type LoginInput struct {
	Phone    string
	Password string
}

type UpdateProfileInput struct {
	FullName  string
	Phone     string
	Password  string
	Companies []Company
}

type Service struct {
	store    Store
	now      func() time.Time
	tokenTTL time.Duration
}

func NewService(store Store, tokenTTL time.Duration) *Service {
	if tokenTTL <= 0 {
		tokenTTL = 72 * time.Hour
	}

	return &Service{
		store:    store,
		now:      time.Now,
		tokenTTL: tokenTTL,
	}
}

func (s *Service) Register(input RegisterInput) (AuthResult, error) {
	fullName, err := normalizeFullName(input.FullName)
	if err != nil {
		return AuthResult{}, err
	}

	phone, err := normalizePhone(input.Phone)
	if err != nil {
		return AuthResult{}, err
	}

	if err := validatePassword(input.Password); err != nil {
		return AuthResult{}, err
	}

	passwordHash, err := HashPassword(input.Password)
	if err != nil {
		return AuthResult{}, fmt.Errorf("hash password: %w", err)
	}

	userID, err := generateUserID()
	if err != nil {
		return AuthResult{}, fmt.Errorf("generate user id: %w", err)
	}

	user := User{
		ID:        userID,
		FullName:  fullName,
		Phone:     phone,
		Companies: []Company{},
		CreatedAt: s.now().UTC(),
	}

	if err := s.store.CreateUser(userRecord{
		User:         user,
		PasswordHash: passwordHash,
	}); err != nil {
		return AuthResult{}, err
	}

	return s.issueSession(user)
}

func (s *Service) Login(input LoginInput) (AuthResult, error) {
	phone, err := normalizePhone(input.Phone)
	if err != nil {
		return AuthResult{}, err
	}

	if strings.TrimSpace(input.Password) == "" {
		return AuthResult{}, newPublicError(ErrValidation, "password is required")
	}

	user, ok, err := s.store.FindUserByPhone(phone)
	if err != nil {
		return AuthResult{}, fmt.Errorf("find user by phone: %w", err)
	}

	if !ok || !VerifyPassword(input.Password, user.PasswordHash) {
		return AuthResult{}, newPublicError(ErrInvalidCredentials, "invalid phone number or password")
	}

	return s.issueSession(user.User)
}

func (s *Service) Authenticate(accessToken string) (User, error) {
	_, user, err := s.resolveAuthorizedRecord(accessToken)
	if err != nil {
		return User{}, err
	}

	return user.User, nil
}

func (s *Service) UpdateProfile(accessToken string, input UpdateProfileInput) (User, error) {
	session, existingUser, err := s.resolveAuthorizedRecord(accessToken)
	if err != nil {
		return User{}, err
	}

	fullName, err := normalizeFullName(input.FullName)
	if err != nil {
		return User{}, err
	}

	phone, err := normalizePhone(input.Phone)
	if err != nil {
		return User{}, err
	}

	passwordHash := existingUser.PasswordHash
	if strings.TrimSpace(input.Password) != "" {
		if err := validatePassword(input.Password); err != nil {
			return User{}, err
		}

		passwordHash, err = HashPassword(input.Password)
		if err != nil {
			return User{}, fmt.Errorf("hash password: %w", err)
		}
	}

	companies, err := normalizeCompanies(input.Companies)
	if err != nil {
		return User{}, err
	}

	updatedUser := userRecord{
		User: User{
			ID:        existingUser.ID,
			FullName:  fullName,
			Phone:     phone,
			Companies: companies,
			CreatedAt: existingUser.CreatedAt,
		},
		PasswordHash: passwordHash,
	}

	if err := s.store.UpdateUser(updatedUser); err != nil {
		if err == ErrNotFound {
			_ = s.store.DeleteSession(session.Token)
			return User{}, newPublicError(ErrUnauthorized, "invalid or expired access token")
		}

		return User{}, err
	}

	return updatedUser.User, nil
}

func (s *Service) DeleteProfile(accessToken string) error {
	session, user, err := s.resolveAuthorizedRecord(accessToken)
	if err != nil {
		return err
	}

	blocker, blocked, err := s.store.GetUserDeletionBlocker(user.ID)
	if err != nil {
		return fmt.Errorf("check delete blockers: %w", err)
	}
	if blocked {
		message := strings.TrimSpace(blocker.Message)
		if message == "" {
			message = "account cannot be deleted"
		}
		return newPublicError(ErrValidation, message)
	}

	if err := s.store.DeleteUser(user.ID); err != nil {
		if err == ErrNotFound {
			_ = s.store.DeleteSession(session.Token)
			return newPublicError(ErrUnauthorized, "invalid or expired access token")
		}

		return fmt.Errorf("delete user: %w", err)
	}

	return nil
}

func (s *Service) resolveAuthorizedRecord(accessToken string) (session, userRecord, error) {
	token := strings.TrimSpace(accessToken)
	if token == "" {
		return session{}, userRecord{}, newPublicError(ErrUnauthorized, "authorization token is required")
	}

	authSession, ok, err := s.store.FindSession(token)
	if err != nil {
		return session{}, userRecord{}, fmt.Errorf("find session: %w", err)
	}

	if !ok {
		return session{}, userRecord{}, newPublicError(ErrUnauthorized, "invalid or expired access token")
	}

	if s.now().UTC().After(authSession.ExpiresAt) {
		_ = s.store.DeleteSession(token)
		return session{}, userRecord{}, newPublicError(ErrUnauthorized, "invalid or expired access token")
	}

	user, ok, err := s.store.FindUserByID(authSession.UserID)
	if err != nil {
		return session{}, userRecord{}, fmt.Errorf("find user by id: %w", err)
	}

	if !ok {
		_ = s.store.DeleteSession(token)
		return session{}, userRecord{}, newPublicError(ErrUnauthorized, "invalid or expired access token")
	}

	return authSession, user, nil
}

func (s *Service) issueSession(user User) (AuthResult, error) {
	now := s.now().UTC()
	accessToken, err := generateAccessToken()
	if err != nil {
		return AuthResult{}, fmt.Errorf("generate access token: %w", err)
	}

	expiresAt := now.Add(s.tokenTTL)
	if err := s.store.SaveSession(session{
		Token:     accessToken,
		UserID:    user.ID,
		CreatedAt: now,
		ExpiresAt: expiresAt,
	}); err != nil {
		return AuthResult{}, fmt.Errorf("save session: %w", err)
	}

	return AuthResult{
		AccessToken: accessToken,
		TokenType:   "Bearer",
		ExpiresAt:   expiresAt,
		User:        user,
	}, nil
}

func normalizeFullName(value string) (string, error) {
	fullName := strings.Join(strings.Fields(value), " ")
	if fullName == "" {
		return "", newPublicError(ErrValidation, "full_name is required")
	}

	if len([]rune(fullName)) < 5 {
		return "", newPublicError(ErrValidation, "full_name must contain at least 5 characters")
	}

	if len([]rune(fullName)) > 120 {
		return "", newPublicError(ErrValidation, "full_name must be 120 characters or fewer")
	}

	return fullName, nil
}

func normalizePhone(value string) (string, error) {
	phone := strings.TrimSpace(value)
	if phone == "" {
		return "", newPublicError(ErrValidation, "phone is required")
	}

	var digits strings.Builder

	for _, symbol := range phone {
		switch {
		case symbol >= '0' && symbol <= '9':
			digits.WriteRune(symbol)
		case symbol == '+' || symbol == ' ' || symbol == '-' || symbol == '(' || symbol == ')':
			continue
		default:
			return "", newPublicError(ErrValidation, "phone contains unsupported characters")
		}
	}

	normalizedDigits := digits.String()
	if len(normalizedDigits) < 10 || len(normalizedDigits) > 15 {
		return "", newPublicError(ErrValidation, "phone must contain 10 to 15 digits")
	}

	// Convert local trunk prefix to international format for common 11-digit numbers.
	if len(normalizedDigits) == 11 && normalizedDigits[0] == '8' {
		normalizedDigits = "7" + normalizedDigits[1:]
	}

	return "+" + normalizedDigits, nil
}

func validatePassword(password string) error {
	if len(strings.TrimSpace(password)) == 0 {
		return newPublicError(ErrValidation, "password is required")
	}

	if len(password) < 8 {
		return newPublicError(ErrValidation, "password must contain at least 8 characters")
	}

	if len(password) > 128 {
		return newPublicError(ErrValidation, "password must be 128 characters or fewer")
	}

	return nil
}

func normalizeCompanies(companies []Company) ([]Company, error) {
	if companies == nil {
		return []Company{}, nil
	}

	normalizedCompanies := make([]Company, 0, len(companies))
	for index, company := range companies {
		name := strings.Join(strings.Fields(company.Name), " ")
		if name == "" {
			return nil, newPublicError(ErrValidation, fmt.Sprintf("companies[%d].name is required", index))
		}
		if len([]rune(name)) > 120 {
			return nil, newPublicError(ErrValidation, fmt.Sprintf("companies[%d].name must be 120 characters or fewer", index))
		}

		country := strings.ToUpper(strings.TrimSpace(company.Country))
		if country == "" {
			return nil, newPublicError(ErrValidation, fmt.Sprintf("companies[%d].country is required", index))
		}
		if len(country) != 2 {
			return nil, newPublicError(ErrValidation, fmt.Sprintf("companies[%d].country must be a 2-letter country code", index))
		}

		iin, err := normalizeIIN(company.IIN)
		if err != nil {
			return nil, newPublicError(ErrValidation, fmt.Sprintf("companies[%d].iin %s", index, err.Error()))
		}

		if country == "KZ" && iin == "" {
			return nil, newPublicError(ErrValidation, fmt.Sprintf("companies[%d].iin is required for Kazakhstan companies", index))
		}

		normalizedCompanies = append(normalizedCompanies, Company{
			Name:    name,
			Country: country,
			IIN:     iin,
		})
	}

	return normalizedCompanies, nil
}

func normalizeIIN(value string) (string, error) {
	trimmed := strings.TrimSpace(value)
	if trimmed == "" {
		return "", nil
	}

	var digits strings.Builder
	for _, symbol := range trimmed {
		if symbol < '0' || symbol > '9' {
			return "", fmt.Errorf("must contain only digits")
		}
		digits.WriteRune(symbol)
	}

	normalized := digits.String()
	if len(normalized) != 12 {
		return "", fmt.Errorf("must contain exactly 12 digits")
	}

	return normalized, nil
}

func generateUserID() (string, error) {
	bytes, err := randomBytes(12)
	if err != nil {
		return "", err
	}

	return "usr_" + hex.EncodeToString(bytes), nil
}

func generateAccessToken() (string, error) {
	bytes, err := randomBytes(32)
	if err != nil {
		return "", err
	}

	return base64.RawURLEncoding.EncodeToString(bytes), nil
}
