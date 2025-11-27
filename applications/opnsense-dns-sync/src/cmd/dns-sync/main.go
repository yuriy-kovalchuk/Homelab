package main

import (
    "log"
    "os"
    "os/signal"
    "syscall"

    "dns-sync/pkg/k8s"
    "dns-sync/pkg/opnsense"
)

func main() {
    // Initialize OPNsense environment & HTTP client
    opnsense.InitEnv()
    opnsense.InitHTTPClient()

    go k8s.StartReconcile()

    sigChan := make(chan os.Signal, 1)
    signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
    <-sigChan

    log.Println("Shutting down gracefully...")
}
