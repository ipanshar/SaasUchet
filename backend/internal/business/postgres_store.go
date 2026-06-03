package business

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"time"
)

const defaultQueryTimeout = 5 * time.Second

type PostgresStore struct {
	db           *sql.DB
	queryTimeout time.Duration
}

func NewPostgresStore(db *sql.DB) *PostgresStore {
	return &PostgresStore{
		db:           db,
		queryTimeout: defaultQueryTimeout,
	}
}

func (s *PostgresStore) ListClients(userID string) ([]Client, error) {
	ctx, cancel := s.withTimeout()
	defer cancel()

	var clients clientsJSON
	err := s.db.QueryRowContext(
		ctx,
		`SELECT clients_json FROM users WHERE id = $1`,
		userID,
	).Scan(&clients)
	if errors.Is(err, sql.ErrNoRows) {
		return []Client{}, nil
	}
	if err != nil {
		return nil, err
	}

	return cloneClients(clients), nil
}

func (s *PostgresStore) SaveClients(userID string, clients []Client) error {
	ctx, cancel := s.withTimeout()
	defer cancel()

	result, err := s.db.ExecContext(
		ctx,
		`UPDATE users SET clients_json = $2 WHERE id = $1`,
		userID,
		mustMarshalClients(clients),
	)
	if err != nil {
		return err
	}

	affectedRows, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if affectedRows == 0 {
		return sql.ErrNoRows
	}

	return nil
}

func (s *PostgresStore) withTimeout() (context.Context, context.CancelFunc) {
	return context.WithTimeout(context.Background(), s.queryTimeout)
}

type clientsJSON []Client

func (c *clientsJSON) Scan(value any) error {
	if value == nil {
		*c = []Client{}
		return nil
	}

	var raw []byte
	switch typed := value.(type) {
	case string:
		raw = []byte(typed)
	case []byte:
		raw = typed
	default:
		return errors.New("unsupported clients_json type")
	}

	if len(raw) == 0 {
		*c = []Client{}
		return nil
	}

	return json.Unmarshal(raw, c)
}

func mustMarshalClients(clients []Client) string {
	if clients == nil {
		clients = []Client{}
	}

	payload, err := json.Marshal(clients)
	if err != nil {
		return "[]"
	}

	return string(payload)
}
