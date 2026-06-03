package business

import "sync"

type Store interface {
	ListClients(userID string) ([]Client, error)
	SaveClients(userID string, clients []Client) error
}

type MemoryStore struct {
	mu            sync.RWMutex
	clientsByUser map[string][]Client
}

func NewMemoryStore() *MemoryStore {
	return &MemoryStore{
		clientsByUser: make(map[string][]Client),
	}
}

func (s *MemoryStore) ListClients(userID string) ([]Client, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	clients := s.clientsByUser[userID]
	return cloneClients(clients), nil
}

func (s *MemoryStore) SaveClients(userID string, clients []Client) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	s.clientsByUser[userID] = cloneClients(clients)
	return nil
}

func cloneClients(clients []Client) []Client {
	cloned := make([]Client, 0, len(clients))
	for _, client := range clients {
		client.Interactions = append([]Interaction(nil), client.Interactions...)
		cloned = append(cloned, client)
	}
	return cloned
}
