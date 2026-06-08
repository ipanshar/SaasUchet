package auth

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"time"

	"github.com/jackc/pgx/v5/pgconn"
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

func (s *PostgresStore) CreateUser(user userRecord) error {
	ctx, cancel := s.withTimeout()
	defer cancel()

	_, err := s.db.ExecContext(
		ctx,
		`INSERT INTO users (id, full_name, phone, password_hash, companies_json, created_at)
		 VALUES ($1, $2, $3, $4, $5, $6)`,
		user.ID,
		user.FullName,
		user.Phone,
		user.PasswordHash,
		mustMarshalCompanies(user.Companies),
		user.CreatedAt,
	)
	if err != nil {
		if isUniqueViolation(err) {
			return newPublicError(ErrPhoneTaken, "user with this phone number already exists")
		}

		return err
	}

	return nil
}

func (s *PostgresStore) FindUserByPhone(phone string) (userRecord, bool, error) {
	ctx, cancel := s.withTimeout()
	defer cancel()

	var user userRecord

	err := s.db.QueryRowContext(
		ctx,
		`SELECT id, full_name, phone, password_hash, companies_json, created_at
		 FROM users
		 WHERE phone = $1`,
		phone,
	).Scan(
		&user.ID,
		&user.FullName,
		&user.Phone,
		&user.PasswordHash,
		(*companiesJSON)(&user.Companies),
		&user.CreatedAt,
	)
	if errors.Is(err, sql.ErrNoRows) {
		return userRecord{}, false, nil
	}

	if err != nil {
		return userRecord{}, false, err
	}

	return user, true, nil
}

func (s *PostgresStore) FindUserByID(id string) (userRecord, bool, error) {
	ctx, cancel := s.withTimeout()
	defer cancel()

	var user userRecord

	err := s.db.QueryRowContext(
		ctx,
		`SELECT id, full_name, phone, password_hash, companies_json, created_at
		 FROM users
		 WHERE id = $1`,
		id,
	).Scan(
		&user.ID,
		&user.FullName,
		&user.Phone,
		&user.PasswordHash,
		(*companiesJSON)(&user.Companies),
		&user.CreatedAt,
	)
	if errors.Is(err, sql.ErrNoRows) {
		return userRecord{}, false, nil
	}

	if err != nil {
		return userRecord{}, false, err
	}

	return user, true, nil
}

func (s *PostgresStore) UpdateUser(user userRecord) error {
	ctx, cancel := s.withTimeout()
	defer cancel()

	result, err := s.db.ExecContext(
		ctx,
		`UPDATE users
		 SET full_name = $2,
		     phone = $3,
		     password_hash = $4,
		     companies_json = $5
		 WHERE id = $1`,
		user.ID,
		user.FullName,
		user.Phone,
		user.PasswordHash,
		mustMarshalCompanies(user.Companies),
	)
	if err != nil {
		if isUniqueViolation(err) {
			return newPublicError(ErrPhoneTaken, "user with this phone number already exists")
		}

		return err
	}

	affectedRows, err := result.RowsAffected()
	if err != nil {
		return err
	}

	if affectedRows == 0 {
		return ErrNotFound
	}

	return nil
}

func (s *PostgresStore) GetUserDeletionBlocker(userID string) (UserDeletionBlocker, bool, error) {
	ctx, cancel := s.withTimeout()
	defer cancel()

	var hasOwnedCompanies bool
	err := s.db.QueryRowContext(
		ctx,
		`SELECT EXISTS (
			SELECT 1
			FROM companies
			WHERE owner_user_id = $1
			  AND archived_at IS NULL
		)`,
		userID,
	).Scan(&hasOwnedCompanies)
	if err != nil {
		return UserDeletionBlocker{}, false, err
	}
	if hasOwnedCompanies {
		return UserDeletionBlocker{
			HasOwnedCompanies: true,
			Message:           "Нельзя удалить аккаунт, пока у вас есть собственные компании. Сначала передайте владение или архивируйте компанию.",
		}, true, nil
	}

	queries := []string{
		`SELECT EXISTS (
			SELECT 1
			FROM clients c
			JOIN companies company ON company.id = c.company_id
			WHERE company.archived_at IS NULL
			  AND (c.created_by_user_id = $1 OR c.updated_by_user_id = $1)
		)`,
		`SELECT EXISTS (
			SELECT 1
			FROM client_interactions ci
			JOIN companies company ON company.id = ci.company_id
			WHERE company.archived_at IS NULL
			  AND ci.author_user_id = $1
		)`,
		`SELECT EXISTS (
			SELECT 1
			FROM warehouses w
			JOIN companies company ON company.id = w.company_id
			WHERE company.archived_at IS NULL
			  AND w.manager_user_id = $1
		)`,
		`SELECT EXISTS (
			SELECT 1
			FROM products p
			JOIN companies company ON company.id = p.company_id
			WHERE company.archived_at IS NULL
			  AND (p.created_by_user_id = $1 OR p.updated_by_user_id = $1)
		)`,
		`SELECT EXISTS (
			SELECT 1
			FROM inventory_documents doc
			JOIN companies company ON company.id = doc.company_id
			WHERE company.archived_at IS NULL
			  AND (doc.created_by_user_id = $1 OR doc.posted_by_user_id = $1)
		)`,
		`SELECT EXISTS (
			SELECT 1
			FROM money_documents doc
			JOIN companies company ON company.id = doc.company_id
			WHERE company.archived_at IS NULL
			  AND (doc.created_by_user_id = $1 OR doc.posted_by_user_id = $1)
		)`,
	}

	for _, query := range queries {
		var hasBusinessHistory bool
		if err := s.db.QueryRowContext(ctx, query, userID).Scan(&hasBusinessHistory); err != nil {
			return UserDeletionBlocker{}, false, err
		}
		if hasBusinessHistory {
			return UserDeletionBlocker{
				HasBusinessHistory: true,
				Message:            "Нельзя удалить аккаунт, потому что в компаниях есть записи, связанные с вашим пользователем.",
			}, true, nil
		}
	}

	return UserDeletionBlocker{}, false, nil
}

func (s *PostgresStore) DeleteUser(userID string) error {
	ctx, cancel := s.withTimeout()
	defer cancel()

	result, err := s.db.ExecContext(
		ctx,
		`DELETE FROM users WHERE id = $1`,
		userID,
	)
	if err != nil {
		return err
	}

	affectedRows, err := result.RowsAffected()
	if err != nil {
		return err
	}

	if affectedRows == 0 {
		return ErrNotFound
	}

	return nil
}

func (s *PostgresStore) SaveSession(authSession session) error {
	ctx, cancel := s.withTimeout()
	defer cancel()

	_, err := s.db.ExecContext(
		ctx,
		`INSERT INTO auth_sessions (token, user_id, created_at, expires_at)
		 VALUES ($1, $2, $3, $4)
		 ON CONFLICT (token) DO UPDATE
		 SET user_id = EXCLUDED.user_id,
		     created_at = EXCLUDED.created_at,
		     expires_at = EXCLUDED.expires_at`,
		authSession.Token,
		authSession.UserID,
		authSession.CreatedAt,
		authSession.ExpiresAt,
	)

	return err
}

func (s *PostgresStore) FindSession(token string) (session, bool, error) {
	ctx, cancel := s.withTimeout()
	defer cancel()

	var authSession session

	err := s.db.QueryRowContext(
		ctx,
		`SELECT token, user_id, created_at, expires_at
		 FROM auth_sessions
		 WHERE token = $1`,
		token,
	).Scan(
		&authSession.Token,
		&authSession.UserID,
		&authSession.CreatedAt,
		&authSession.ExpiresAt,
	)
	if errors.Is(err, sql.ErrNoRows) {
		return session{}, false, nil
	}

	if err != nil {
		return session{}, false, err
	}

	return authSession, true, nil
}

func (s *PostgresStore) DeleteSession(token string) error {
	ctx, cancel := s.withTimeout()
	defer cancel()

	_, err := s.db.ExecContext(
		ctx,
		`DELETE FROM auth_sessions WHERE token = $1`,
		token,
	)

	return err
}

func (s *PostgresStore) withTimeout() (context.Context, context.CancelFunc) {
	return context.WithTimeout(context.Background(), s.queryTimeout)
}

func isUniqueViolation(err error) bool {
	var pgErr *pgconn.PgError
	return errors.As(err, &pgErr) && pgErr.Code == "23505"
}

type companiesJSON []Company

func (c *companiesJSON) Scan(value any) error {
	if value == nil {
		*c = []Company{}
		return nil
	}

	var raw []byte
	switch typed := value.(type) {
	case string:
		raw = []byte(typed)
	case []byte:
		raw = typed
	default:
		return errors.New("unsupported companies_json type")
	}

	if len(raw) == 0 {
		*c = []Company{}
		return nil
	}

	return json.Unmarshal(raw, c)
}

func mustMarshalCompanies(companies []Company) string {
	if companies == nil {
		companies = []Company{}
	}

	payload, err := json.Marshal(companies)
	if err != nil {
		return "[]"
	}

	return string(payload)
}
