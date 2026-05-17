package main

import (
	"context"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/quantumworld-dpdns-io/zk-device-identity-saas/internal/api"
	"github.com/quantumworld-dpdns-io/zk-device-identity-saas/internal/config"
	"github.com/quantumworld-dpdns-io/zk-device-identity-saas/internal/db"
	"github.com/quantumworld-dpdns-io/zk-device-identity-saas/internal/seeder"
)

func main() {
	cfg := config.Load()

	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelDebug,
	})))

	postgresDB, err := db.NewPostgresDB(cfg)
	if err != nil {
		slog.Error("failed to connect to postgres", "error", err)
		os.Exit(1)
	}
	slog.Info("connected to postgres")

	redisClient := db.NewRedisClient(cfg)
	defer redisClient.Close()
	slog.Info("connected to redis")

	qdrantConn, _, err := db.NewQdrantClient(cfg)
	if err != nil {
		slog.Warn("failed to connect to qdrant", "error", err)
	} else {
		defer qdrantConn.Close()
		slog.Info("connected to qdrant")
	}

	if cfg.GoEnv == "development" {
		seeder.Run(postgresDB, cfg)
	}

	router := api.NewRouter(cfg, postgresDB, redisClient)

	srv := &http.Server{
		Addr:         ":" + cfg.GoPort,
		Handler:      router,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	go func() {
		slog.Info("starting server", "port", cfg.GoPort)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			slog.Error("server error", "error", err)
			os.Exit(1)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	slog.Info("shutting down server...")

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := srv.Shutdown(ctx); err != nil {
		slog.Error("server forced to shutdown", "error", err)
		os.Exit(1)
	}

	slog.Info("server exited")
}
