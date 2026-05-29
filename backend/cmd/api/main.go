package main

import (
	"context"
	"errors"
	"log"
	stdhttp "net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/altyncloud/saas-uchet/backend/internal/auth"
	"github.com/altyncloud/saas-uchet/backend/internal/config"
	"github.com/altyncloud/saas-uchet/backend/internal/database"
	transporthttp "github.com/altyncloud/saas-uchet/backend/internal/http"
)

func main() {
	cfg := config.Load()
	startupCtx, startupCancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer startupCancel()

	db, err := database.OpenPostgres(startupCtx, cfg)
	if err != nil {
		log.Fatalf("database setup failed: %v", err)
	}
	defer db.Close()

	authStore := auth.NewPostgresStore(db)
	authService := auth.NewService(authStore, cfg.AuthTokenTTL)
	authHandler := auth.NewHandler(authService)

	server := &stdhttp.Server{
		Addr:              ":" + cfg.Port,
		Handler:           transporthttp.NewRouter(cfg, authHandler),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      10 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	serverErrors := make(chan error, 1)

	go func() {
		log.Printf("%s listening on http://localhost:%s", cfg.AppName, cfg.Port)

		if serveErr := server.ListenAndServe(); serveErr != nil && !errors.Is(serveErr, stdhttp.ErrServerClosed) {
			serverErrors <- serveErr
		}

		close(serverErrors)
	}()

	shutdownSignals, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	select {
	case err, ok := <-serverErrors:
		if ok && err != nil {
			log.Fatalf("server failed: %v", err)
		}
	case <-shutdownSignals.Done():
		log.Println("shutdown signal received")

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		if err := server.Shutdown(ctx); err != nil {
			log.Fatalf("graceful shutdown failed: %v", err)
		}

		log.Println("server stopped")
	}
}
