package auth

import (
	"encoding/json"
	"errors"
	"io"
	"log"
	"net/http"
	"strings"

	"github.com/altyncloud/saas-uchet/backend/internal/response"
)

type Handler struct {
	service *Service
}

type registerRequest struct {
	FullName string `json:"full_name"`
	Phone    string `json:"phone"`
	Password string `json:"password"`
}

type loginRequest struct {
	Phone    string `json:"phone"`
	Password string `json:"password"`
}

type updateProfileRequest struct {
	FullName  string    `json:"full_name"`
	Phone     string    `json:"phone"`
	Password  string    `json:"password"`
	Companies []Company `json:"companies"`
}

func NewHandler(service *Service) Handler {
	return Handler{
		service: service,
	}
}

func (h Handler) Register(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		response.Error(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}

	var request registerRequest
	if err := decodeJSON(r.Body, &request); err != nil {
		response.Error(w, http.StatusBadRequest, err.Error())
		return
	}

	authResult, err := h.service.Register(RegisterInput{
		FullName: request.FullName,
		Phone:    request.Phone,
		Password: request.Password,
	})
	if err != nil {
		writeAuthError(w, err)
		return
	}

	response.JSON(w, http.StatusCreated, authResult)
}

func (h Handler) Login(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		response.Error(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}

	var request loginRequest
	if err := decodeJSON(r.Body, &request); err != nil {
		response.Error(w, http.StatusBadRequest, err.Error())
		return
	}

	authResult, err := h.service.Login(LoginInput{
		Phone:    request.Phone,
		Password: request.Password,
	})
	if err != nil {
		writeAuthError(w, err)
		return
	}

	response.JSON(w, http.StatusOK, authResult)
}

func (h Handler) Me(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		response.Error(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}

	accessToken, err := extractBearerToken(r.Header.Get("Authorization"))
	if err != nil {
		response.Error(w, http.StatusUnauthorized, err.Error())
		return
	}

	user, err := h.service.Authenticate(accessToken)
	if err != nil {
		writeAuthError(w, err)
		return
	}

	response.JSON(w, http.StatusOK, user)
}

func (h Handler) Profile(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		h.Me(w, r)
	case http.MethodPut:
		h.UpdateProfile(w, r)
	case http.MethodDelete:
		h.DeleteProfile(w, r)
	default:
		response.Error(w, http.StatusMethodNotAllowed, "method not allowed")
	}
}

func (h Handler) UpdateProfile(w http.ResponseWriter, r *http.Request) {
	accessToken, err := extractBearerToken(r.Header.Get("Authorization"))
	if err != nil {
		response.Error(w, http.StatusUnauthorized, err.Error())
		return
	}

	var request updateProfileRequest
	if err := decodeJSON(r.Body, &request); err != nil {
		response.Error(w, http.StatusBadRequest, err.Error())
		return
	}

	user, err := h.service.UpdateProfile(accessToken, UpdateProfileInput{
		FullName:  request.FullName,
		Phone:     request.Phone,
		Password:  request.Password,
		Companies: request.Companies,
	})
	if err != nil {
		writeAuthError(w, err)
		return
	}

	response.JSON(w, http.StatusOK, user)
}

func (h Handler) DeleteProfile(w http.ResponseWriter, r *http.Request) {
	accessToken, err := extractBearerToken(r.Header.Get("Authorization"))
	if err != nil {
		response.Error(w, http.StatusUnauthorized, err.Error())
		return
	}

	if err := h.service.DeleteProfile(accessToken); err != nil {
		writeAuthError(w, err)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

func decodeJSON(body io.ReadCloser, destination any) error {
	defer body.Close()

	decoder := json.NewDecoder(body)
	decoder.DisallowUnknownFields()

	if err := decoder.Decode(destination); err != nil {
		if errors.Is(err, io.EOF) {
			return newPublicError(ErrValidation, "request body is required")
		}

		return newPublicError(ErrValidation, "request body must be valid JSON")
	}

	var trailingPayload any
	if err := decoder.Decode(&trailingPayload); !errors.Is(err, io.EOF) {
		return newPublicError(ErrValidation, "request body must contain a single JSON object")
	}

	return nil
}

func extractBearerToken(headerValue string) (string, error) {
	if strings.TrimSpace(headerValue) == "" {
		return "", newPublicError(ErrUnauthorized, "authorization header is required")
	}

	parts := strings.SplitN(headerValue, " ", 2)
	if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") || strings.TrimSpace(parts[1]) == "" {
		return "", newPublicError(ErrUnauthorized, "authorization header must use Bearer token")
	}

	return strings.TrimSpace(parts[1]), nil
}

func writeAuthError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, ErrValidation):
		response.Error(w, http.StatusBadRequest, err.Error())
	case errors.Is(err, ErrPhoneTaken):
		response.Error(w, http.StatusConflict, err.Error())
	case errors.Is(err, ErrInvalidCredentials):
		response.Error(w, http.StatusUnauthorized, err.Error())
	case errors.Is(err, ErrUnauthorized):
		response.Error(w, http.StatusUnauthorized, err.Error())
	default:
		log.Printf("auth request failed: %v", err)
		response.Error(w, http.StatusInternalServerError, "internal server error")
	}
}
