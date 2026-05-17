package vto

type ErrorResponse struct {
	Code    int         `json:"code"`
	Message string      `json:"message"`
	Details interface{} `json:"details,omitempty"`
}

type ValidationErrorResponse struct {
	Code    int               `json:"code"`
	Message string            `json:"message"`
	Errors  map[string]string `json:"errors"`
}
