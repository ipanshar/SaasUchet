package database

import (
	"context"
	"database/sql"
	"embed"
	"fmt"
	"io/fs"
	"sort"
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
	statements := make([]string, 0, 16)
	var current []rune
	inSingleQuote := false
	inDoubleQuote := false
	dollarTag := ""

	for index := 0; index < len(schema); index++ {
		ch := rune(schema[index])

		if dollarTag == "" && !inSingleQuote && !inDoubleQuote && ch == '$' {
			tagEnd := index + 1
			for tagEnd < len(schema) {
				next := rune(schema[tagEnd])
				if next == '$' {
					tag := schema[index : tagEnd+1]
					dollarTag = tag
					current = append(current, []rune(tag)...)
					index = tagEnd
					goto continueLoop
				}
				if !(next == '_' || (next >= '0' && next <= '9') || (next >= 'A' && next <= 'Z') || (next >= 'a' && next <= 'z')) {
					break
				}
				tagEnd++
			}
		}

		if dollarTag != "" {
			if hasPrefixAt(schema, index, dollarTag) {
				current = append(current, []rune(dollarTag)...)
				index += len(dollarTag) - 1
				dollarTag = ""
				goto continueLoop
			}
			current = append(current, ch)
			goto continueLoop
		}

		if ch == '\'' && !inDoubleQuote {
			if !inSingleQuote {
				inSingleQuote = true
			} else if index+1 < len(schema) && schema[index+1] == '\'' {
				current = append(current, ch, ch)
				index++
				goto continueLoop
			} else {
				inSingleQuote = false
			}
		} else if ch == '"' && !inSingleQuote {
			inDoubleQuote = !inDoubleQuote
		}

		if ch == ';' && !inSingleQuote && !inDoubleQuote {
			if trimmed := trimWhitespace(string(current)); trimmed != "" {
				statements = append(statements, trimmed)
			}
			current = current[:0]
			goto continueLoop
		}

		current = append(current, ch)

	continueLoop:
	}

	if trimmed := trimWhitespace(string(current)); trimmed != "" {
		statements = append(statements, trimmed)
	}

	return statements
}

func hasPrefixAt(value string, index int, prefix string) bool {
	return index+len(prefix) <= len(value) && value[index:index+len(prefix)] == prefix
}

func trimWhitespace(value string) string {
	start := 0
	for start < len(value) {
		switch value[start] {
		case ' ', '\n', '\r', '\t':
			start++
		default:
			goto foundStart
		}
	}
	return ""

foundStart:
	end := len(value)
	for end > start {
		switch value[end-1] {
		case ' ', '\n', '\r', '\t':
			end--
		default:
			return value[start:end]
		}
	}
	return value[start:end]
}
