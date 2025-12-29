package main

import (
    "fmt"
    "log/slog"
    "os"
    "strings"
    "sync"
    "update-checker/internal/models"
    "update-checker/pkg"
    "update-checker/pkg/locals"
)

func main() {

    searchPath := mustGetEnv("SEARCH_PATH")

    var allChartFiles []string
    locals.GetAllChartsPaths(searchPath, &allChartFiles)

    var wg sync.WaitGroup
    sem := make(chan struct{}, 50)

    for _, file := range allChartFiles {
        chart := locals.ParseChart(file)

        wg.Add(1)
        sem <- struct{}{}

        go func(c models.Chart) {
            defer wg.Done()
            defer func() { <-sem }()
            pkg.CheckNewChartVersion(c)
        }(chart)
    }

    wg.Wait()

}

func mustGetEnv(name string) string {
    envValue := strings.TrimSpace(os.Getenv(name))
    if envValue == "" {
        slog.Error(fmt.Sprintf("%s must be set", name))
        os.Exit(22)
    }
    return envValue
}
