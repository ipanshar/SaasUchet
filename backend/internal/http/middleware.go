package transporthttp

import (
	"log"
	stdhttp "net/http"
	"slices"
	"time"

	"github.com/altyncloud/saas-uchet/backend/internal/response"
)

func withCORS(next stdhttp.Handler, allowedOrigins []string) stdhttp.Handler {
	return stdhttp.HandlerFunc(func(w stdhttp.ResponseWriter, r *stdhttp.Request) {
		origin := r.Header.Get("Origin")

		if len(allowedOrigins) == 0 || slices.Contains(allowedOrigins, "*") {
			w.Header().Set("Access-Control-Allow-Origin", "*")
		} else if origin != "" && slices.Contains(allowedOrigins, origin) {
			w.Header().Set("Access-Control-Allow-Origin", origin)
			w.Header().Set("Vary", "Origin")
		}

		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")

		if r.Method == stdhttp.MethodOptions {
			w.WriteHeader(stdhttp.StatusNoContent)
			return
		}

		next.ServeHTTP(w, r)
	})
}

func withLogging(next stdhttp.Handler) stdhttp.Handler {
	return stdhttp.HandlerFunc(func(w stdhttp.ResponseWriter, r *stdhttp.Request) {
		startedAt := time.Now()
		next.ServeHTTP(w, r)
		log.Printf("%s %s %s", r.Method, r.URL.Path, time.Since(startedAt).Round(time.Millisecond))
	})
}

func withRecovery(next stdhttp.Handler) stdhttp.Handler {
	return stdhttp.HandlerFunc(func(w stdhttp.ResponseWriter, r *stdhttp.Request) {
		defer func() {
			if recovered := recover(); recovered != nil {
				log.Printf("panic recovered: %v", recovered)
				response.Error(w, stdhttp.StatusInternalServerError, "internal server error")
			}
		}()

		next.ServeHTTP(w, r)
	})
}
