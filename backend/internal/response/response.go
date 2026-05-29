package response

import (
	"encoding/json"
	"log"
	stdhttp "net/http"
)

func JSON(w stdhttp.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)

	if err := json.NewEncoder(w).Encode(payload); err != nil {
		log.Printf("write json response: %v", err)
	}
}

func Error(w stdhttp.ResponseWriter, status int, message string) {
	JSON(w, status, map[string]string{
		"error": message,
	})
}
