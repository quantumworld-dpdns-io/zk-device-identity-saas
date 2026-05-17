package db

import (
	"github.com/quantumworld-dpdns-io/zk-device-identity-saas/internal/config"
	"github.com/redis/go-redis/v9"
)

func NewRedisClient(cfg *config.Config) *redis.Client {
	return redis.NewClient(&redis.Options{
		Addr:     cfg.RedisHost + ":" + cfg.RedisPort,
		Password: cfg.RedisPassword,
		DB:       0,
	})
}
