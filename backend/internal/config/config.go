package config

import (
	"bufio"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"
)

var loadEnvOnce sync.Once

type Config struct {
	Port                 string
	AppName              string
	AppVersion           string
	DatabaseURL          string
	DatabaseMaxOpenConns int
	DatabaseMaxIdleConns int
	DatabaseMaxIdleTime  time.Duration
	AuthTokenTTL         time.Duration
	AllowedOrigins       []string
}

func Load() Config {
	loadEnvOnce.Do(loadEnvFile)

	return Config{
		Port:                 getEnv("PORT", "8080"),
		AppName:              getEnv("APP_NAME", "saas-uchet-api"),
		AppVersion:           getEnv("APP_VERSION", "0.1.0"),
		DatabaseURL:          getEnv("DATABASE_URL", "postgres://postgres:postgres@localhost:5432/saas_uchet?sslmode=disable"),
		DatabaseMaxOpenConns: getInt("DATABASE_MAX_OPEN_CONNS", 10),
		DatabaseMaxIdleConns: getInt("DATABASE_MAX_IDLE_CONNS", 5),
		DatabaseMaxIdleTime:  getDurationMinutes("DATABASE_MAX_IDLE_MINUTES", 15),
		AuthTokenTTL:         getDurationHours("AUTH_TOKEN_TTL_HOURS", 72),
		AllowedOrigins:       splitCSV(getEnv("ALLOWED_ORIGINS", "*")),
	}
}

func loadEnvFile() {
	for _, candidate := range []string{".env", filepath.Join("backend", ".env")} {
		if err := loadEnvFromPath(candidate); err == nil {
			return
		}
	}
}

func loadEnvFromPath(path string) error {
	file, err := os.Open(path)
	if err != nil {
		return err
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}

		key, value, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}

		key = strings.TrimSpace(key)
		if key == "" {
			continue
		}

		if _, exists := os.LookupEnv(key); exists {
			continue
		}

		value = strings.Trim(strings.TrimSpace(value), `"'`)
		_ = os.Setenv(key, value)
	}

	return scanner.Err()
}

func getEnv(key string, fallback string) string {
	if value := strings.TrimSpace(os.Getenv(key)); value != "" {
		return value
	}

	return fallback
}

func getInt(key string, fallback int) int {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback
	}

	parsed, err := strconv.Atoi(value)
	if err != nil || parsed <= 0 {
		return fallback
	}

	return parsed
}

func getDurationHours(key string, fallback int) time.Duration {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return time.Duration(fallback) * time.Hour
	}

	hours, err := strconv.Atoi(value)
	if err != nil || hours <= 0 {
		return time.Duration(fallback) * time.Hour
	}

	return time.Duration(hours) * time.Hour
}

func getDurationMinutes(key string, fallback int) time.Duration {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return time.Duration(fallback) * time.Minute
	}

	minutes, err := strconv.Atoi(value)
	if err != nil || minutes <= 0 {
		return time.Duration(fallback) * time.Minute
	}

	return time.Duration(minutes) * time.Minute
}

func splitCSV(value string) []string {
	if strings.TrimSpace(value) == "" {
		return []string{"*"}
	}

	parts := strings.Split(value, ",")
	items := make([]string, 0, len(parts))

	for _, part := range parts {
		if trimmed := strings.TrimSpace(part); trimmed != "" {
			items = append(items, trimmed)
		}
	}

	if len(items) == 0 {
		return []string{"*"}
	}

	return items
}
