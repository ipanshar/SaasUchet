package database

import (
	"context"
	"database/sql"
	"embed"
	"fmt"
	"io/fs"
	"sort"
	"strings"
	"time"

	"github.com/altyncloud/saas-uchet/backend/internal/config"
	_ "github.com/jackc/pgx/v5/stdlib"
)

//go:embed schema/*.sql
var schemaFiles embed.FS

func OpenPostgres(ctx context.Context, cfg config.Config) (*sql.DB, error) {
	db, err := sql.Open("pgx", cfg.DatabaseURL)
	if err != nil {
		return nil, fmt.Errorf("open postgres connection: %w", err)
	}

	db.SetMaxOpenConns(cfg.DatabaseMaxOpenConns)
	db.SetMaxIdleConns(cfg.DatabaseMaxIdleConns)
	db.SetConnMaxIdleTime(cfg.DatabaseMaxIdleTime)

	pingCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()

	if err := db.PingContext(pingCtx); err != nil {
		db.Close()
		return nil, fmt.Errorf("ping postgres: %w", err)
	}

	if err := applySchema(ctx, db); err != nil {
		db.Close()
		return nil, err
	}

	return db, nil
}

func applySchema(ctx context.Context, db *sql.DB) error {
	migrations, err := fs.Glob(schemaFiles, "schema/*.sql")
	if err != nil {
		return fmt.Errorf("list postgres schema files: %w", err)
	}

	sort.Strings(migrations)

	for _, migrationPath := range migrations {
		schema, err := schemaFiles.ReadFile(migrationPath)
		if err != nil {
			return fmt.Errorf("read postgres schema %s: %w", migrationPath, err)
		}

		for _, statement := range splitSQLStatements(string(schema)) {
			migrationCtx, cancel := context.WithTimeout(ctx, 10*time.Second)
			_, execErr := db.ExecContext(migrationCtx, statement)
			cancel()

			if execErr != nil {
				return fmt.Errorf("apply postgres schema %s: %w", migrationPath, execErr)
			}
		}
	}

	return nil
}

func splitSQLStatements(schema string) []string {
	rawStatements := strings.Split(schema, ";")
	statements := make([]string, 0, len(rawStatements))

	for _, statement := range rawStatements {
		trimmed := strings.TrimSpace(statement)
		if trimmed != "" {
			statements = append(statements, trimmed)
		}
	}

	return statements
}
