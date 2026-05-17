package db

import (
	"fmt"

	"github.com/quantumworld-dpdns-io/zk-device-identity-saas/internal/config"
	qdrant "github.com/qdrant/go-client/qdrant"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

func NewQdrantClient(cfg *config.Config) (*grpc.ClientConn, qdrant.CollectionsClient, error) {
	addr := fmt.Sprintf("%s:%s", cfg.QdrantHost, cfg.QdrantPort)
	conn, err := grpc.Dial(addr, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		return nil, nil, fmt.Errorf("failed to connect to qdrant: %w", err)
	}
	collectionsClient := qdrant.NewCollectionsClient(conn)
	return conn, collectionsClient, nil
}
