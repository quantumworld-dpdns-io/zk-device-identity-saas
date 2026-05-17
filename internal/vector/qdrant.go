package vector

import (
	"context"
	"fmt"
	"log/slog"

	"github.com/google/uuid"
	"github.com/quantumworld-dpdns-io/zk-device-identity-saas/internal/config"
	qdrant "github.com/qdrant/go-client/qdrant"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

type QdrantClient struct {
	conn          *grpc.ClientConn
	collections   qdrant.CollectionsClient
	points        qdrant.PointsClient
	collectionName string
}

func NewQdrantClient(cfg *config.Config) (*QdrantClient, error) {
	addr := fmt.Sprintf("%s:%s", cfg.QdrantHost, cfg.QdrantPort)
	conn, err := grpc.Dial(addr, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		return nil, fmt.Errorf("failed to connect to qdrant: %w", err)
	}

	collectionName := cfg.QdrantCollection
	if collectionName == "" {
		collectionName = "device_fingerprints"
	}

	client := &QdrantClient{
		conn:           conn,
		collections:    qdrant.NewCollectionsClient(conn),
		points:         qdrant.NewPointsClient(conn),
		collectionName: collectionName,
	}

	return client, nil
}

func (c *QdrantClient) Close() error {
	return c.conn.Close()
}

func (c *QdrantClient) InitCollection(vectorSize uint64) error {
	ctx := context.Background()

	exists, err := c.collectionExists(ctx)
	if err != nil {
		return fmt.Errorf("failed to check collection existence: %w", err)
	}

	if exists {
		slog.Info("qdrant collection already exists", "name", c.collectionName)
		return nil
	}

	distance := qdrant.Distance_Cosine
	_, err = c.collections.Create(ctx, &qdrant.CreateCollection{
		CollectionName: c.collectionName,
		VectorsConfig: &qdrant.VectorsConfig{
			Config: &qdrant.VectorsConfig_Params{
				Params: &qdrant.VectorParams{
					Size:     vectorSize,
					Distance: distance,
				},
			},
		},
	})
	if err != nil {
		return fmt.Errorf("failed to create qdrant collection: %w", err)
	}

	slog.Info("qdrant collection created", "name", c.collectionName, "size", vectorSize)
	return nil
}

func (c *QdrantClient) UpsertFingerprint(deviceID string, embedding []float32) error {
	ctx := context.Background()

	pointID := uuid.New().String()
	_, err := c.points.Upsert(ctx, &qdrant.UpsertPoints{
		CollectionName: c.collectionName,
		Points: []*qdrant.PointStruct{
			{
				Id: newPointID(pointID),
				Vectors: &qdrant.Vectors{
					VectorsOptions: &qdrant.Vectors_Vector{
						Vector: &qdrant.Vector{
							Data: embedding,
						},
					},
				},
				Payload: map[string]*qdrant.Value{
					"device_id": {
						Kind: &qdrant.Value_StringValue{
							StringValue: deviceID,
						},
					},
				},
			},
		},
	})
	if err != nil {
		return fmt.Errorf("failed to upsert fingerprint: %w", err)
	}

	slog.Info("fingerprint upserted", "device_id", deviceID, "point_id", pointID)
	return nil
}

func (c *QdrantClient) SearchSimilar(embedding []float32, limit int) ([]string, error) {
	ctx := context.Background()

	resp, err := c.points.Search(ctx, &qdrant.SearchPoints{
		CollectionName: c.collectionName,
		Vector:         embedding,
		Limit:          uint64(limit),
		WithPayload:    &qdrant.WithPayloadSelector{SelectorOptions: &qdrant.WithPayloadSelector_Enable{Enable: true}},
	})
	if err != nil {
		return nil, fmt.Errorf("failed to search similar points: %w", err)
	}

	deviceIDs := make([]string, 0, len(resp.GetResult()))
	for _, point := range resp.GetResult() {
		if payload, ok := point.GetPayload()["device_id"]; ok {
			if val, ok := payload.GetKind().(*qdrant.Value_StringValue); ok {
				deviceIDs = append(deviceIDs, val.StringValue)
			}
		}
	}

	return deviceIDs, nil
}

func (c *QdrantClient) DeleteFingerprint(deviceID string) error {
	ctx := context.Background()

	filter := &qdrant.Filter{
		Must: []*qdrant.Condition{
			{
				ConditionOneOf: &qdrant.Condition_Field{
					Field: &qdrant.FieldCondition{
						Key: "device_id",
						Match: &qdrant.Match{
							MatchValue: &qdrant.Match_Keyword{
								Keyword: deviceID,
							},
						},
					},
				},
			},
		},
	}

	_, err := c.points.Delete(ctx, &qdrant.DeletePoints{
		CollectionName: c.collectionName,
		Points: &qdrant.PointsSelector{
			PointsSelectorOneOf: &qdrant.PointsSelector_Filter{
				Filter: filter,
			},
		},
	})
	if err != nil {
		return fmt.Errorf("failed to delete fingerprint: %w", err)
	}

	slog.Info("fingerprint deleted", "device_id", deviceID)
	return nil
}

func (c *QdrantClient) collectionExists(ctx context.Context) (bool, error) {
	resp, err := c.collections.List(ctx, &qdrant.ListCollectionsRequest{})
	if err != nil {
		return false, err
	}

	for _, col := range resp.GetCollections() {
		if col.GetName() == c.collectionName {
			return true, nil
		}
	}
	return false, nil
}

func newPointID(id string) *qdrant.PointId {
	return &qdrant.PointId{
		PointIdOptions: &qdrant.PointId_Uuid{
			Uuid: id,
		},
	}
}
