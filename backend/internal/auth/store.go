package auth

import "sync"

type Store interface {
	CreateUser(user userRecord) error
	FindUserByPhone(phone string) (userRecord, bool, error)
	FindUserByID(id string) (userRecord, bool, error)
	UpdateUser(user userRecord) error
	DeleteUser(userID string) error
	SaveSession(session session) error
	FindSession(token string) (session, bool, error)
	DeleteSession(token string) error
}

type MemoryStore struct {
	mu              sync.RWMutex
	usersByPhone    map[string]userRecord
	usersByID       map[string]userRecord
	sessionsByToken map[string]session
}

func NewMemoryStore() *MemoryStore {
	return &MemoryStore{
		usersByPhone:    make(map[string]userRecord),
		usersByID:       make(map[string]userRecord),
		sessionsByToken: make(map[string]session),
	}
}

func (s *MemoryStore) CreateUser(user userRecord) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if _, exists := s.usersByPhone[user.Phone]; exists {
		return newPublicError(ErrPhoneTaken, "user with this phone number already exists")
	}

	s.usersByPhone[user.Phone] = user
	s.usersByID[user.ID] = user

	return nil
}

func (s *MemoryStore) FindUserByPhone(phone string) (userRecord, bool, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	user, ok := s.usersByPhone[phone]
	return user, ok, nil
}

func (s *MemoryStore) FindUserByID(id string) (userRecord, bool, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	user, ok := s.usersByID[id]
	return user, ok, nil
}

func (s *MemoryStore) UpdateUser(user userRecord) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	existingUser, ok := s.usersByID[user.ID]
	if !ok {
		return ErrNotFound
	}

	if existingByPhone, exists := s.usersByPhone[user.Phone]; exists && existingByPhone.ID != user.ID {
		return newPublicError(ErrPhoneTaken, "user with this phone number already exists")
	}

	if existingUser.Phone != user.Phone {
		delete(s.usersByPhone, existingUser.Phone)
	}

	s.usersByID[user.ID] = user
	s.usersByPhone[user.Phone] = user

	return nil
}

func (s *MemoryStore) DeleteUser(userID string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	user, ok := s.usersByID[userID]
	if !ok {
		return ErrNotFound
	}

	delete(s.usersByID, userID)
	delete(s.usersByPhone, user.Phone)

	for token, session := range s.sessionsByToken {
		if session.UserID == userID {
			delete(s.sessionsByToken, token)
		}
	}

	return nil
}

func (s *MemoryStore) SaveSession(session session) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	s.sessionsByToken[session.Token] = session
	return nil
}

func (s *MemoryStore) FindSession(token string) (session, bool, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	session, ok := s.sessionsByToken[token]
	return session, ok, nil
}

func (s *MemoryStore) DeleteSession(token string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	delete(s.sessionsByToken, token)
	return nil
}
