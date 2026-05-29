package health

import (
	"net/http"
	"time"

	"github.com/altyncloud/saas-uchet/backend/internal/response"
)

type Handler struct {
	appName    string
	appVersion string
}

type StatusResponse struct {
	Status    string `json:"status"`
	Service   string `json:"service"`
	Version   string `json:"version"`
	Timestamp string `json:"timestamp"`
}

func NewHandler(appName string, appVersion string) Handler {
	return Handler{
		appName:    appName,
		appVersion: appVersion,
	}
}

func (h Handler) Get(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		response.Error(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}

	response.JSON(w, http.StatusOK, StatusResponse{
		Status:    "ok",
		Service:   h.appName,
		Version:   h.appVersion,
		Timestamp: time.Now().UTC().Format(time.RFC3339),
	})
}
