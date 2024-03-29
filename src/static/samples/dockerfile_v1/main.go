package main

import (
	"flag"
	"fmt"
	"net/http"
)

func main() {
	var port int

	flag.IntVar(&port, "port", 8080, "TCP port number where app should wait for connections")
	flag.Parse()

	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", healthz)
	mux.HandleFunc("/", hello)

	address := fmt.Sprintf(":%d", port)

	fmt.Println("Running web server on", address)

	server := &http.Server{
		Addr:    address,
		Handler: mux,
	}

	server.ListenAndServe()

	fmt.Println("Web server turned off")
}

func healthz(w http.ResponseWriter, r *http.Request) {
	fmt.Fprintln(w, "WORKING")
}

func hello(w http.ResponseWriter, r *http.Request) {
	fmt.Fprintln(w, "Hello world!")
}
