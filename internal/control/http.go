package control

import "net/http"

type handler struct{}

func NewHandler() http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        if r.URL.Path != "/health" {
            http.NotFound(w, r)
            return
        }
        w.WriteHeader(http.StatusOK)
    })
}
