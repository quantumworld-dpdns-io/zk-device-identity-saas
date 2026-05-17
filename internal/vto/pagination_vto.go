package vto

type PaginatedResponse struct {
	Data       []interface{} `json:"data"`
	Page       int           `json:"page"`
	PageSize   int           `json:"page_size"`
	TotalItems int64         `json:"total_items"`
	TotalPages int           `json:"total_pages"`
}
