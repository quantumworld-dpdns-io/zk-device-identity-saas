package main

import (
	"fmt"
	"os"

	"github.com/quantumworld-dpdns-io/zk-device-identity-saas/internal/config"
	"github.com/quantumworld-dpdns-io/zk-device-identity-saas/internal/db"
	"github.com/quantumworld-dpdns-io/zk-device-identity-saas/internal/seeder"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Println("usage: go run cmd/migrate/main.go <migrate|seed>")
		os.Exit(1)
	}

	cfg := config.Load()

	postgresDB, err := db.NewPostgresDB(cfg)
	if err != nil {
		fmt.Printf("error connecting to database: %v\n", err)
		os.Exit(1)
	}

	switch os.Args[1] {
	case "migrate":
		fmt.Println("migrations already run via AutoMigrate")
	case "seed":
		seeder.Run(postgresDB, cfg)
		fmt.Println("database seeded successfully")
	default:
		fmt.Printf("unknown command: %s\n", os.Args[1])
		fmt.Println("usage: go run cmd/migrate/main.go <migrate|seed>")
		os.Exit(1)
	}
}
