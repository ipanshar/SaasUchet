package business

import (
	"errors"
	"net/http"
	"strings"

	"github.com/altyncloud/saas-uchet/backend/internal/auth"
	"github.com/altyncloud/saas-uchet/backend/internal/response"
)

type Authenticator interface {
	Authenticate(accessToken string) (auth.User, error)
}

type Handler struct {
	authenticator Authenticator
}

func NewHandler(authenticator Authenticator) Handler {
	return Handler{authenticator: authenticator}
}

func (h Handler) Overview(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		response.Error(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}

	accessToken, err := extractBearerToken(r.Header.Get("Authorization"))
	if err != nil {
		response.Error(w, http.StatusUnauthorized, err.Error())
		return
	}

	user, err := h.authenticator.Authenticate(accessToken)
	if err != nil {
		if errors.Is(err, auth.ErrUnauthorized) {
			response.Error(w, http.StatusUnauthorized, err.Error())
			return
		}

		response.Error(w, http.StatusInternalServerError, "internal server error")
		return
	}

	response.JSON(w, http.StatusOK, buildOverview(user))
}

func extractBearerToken(headerValue string) (string, error) {
	if strings.TrimSpace(headerValue) == "" {
		return "", errors.New("authorization header is required")
	}

	parts := strings.SplitN(headerValue, " ", 2)
	if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") || strings.TrimSpace(parts[1]) == "" {
		return "", errors.New("authorization header must use Bearer token")
	}

	return strings.TrimSpace(parts[1]), nil
}
