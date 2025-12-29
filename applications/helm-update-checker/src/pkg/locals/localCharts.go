package locals

import (
    "gopkg.in/yaml.v3"
    "log/slog"
    "os"
    "path/filepath"
    "strings"
    "update-checker/internal/models"
)

func GetAllChartsPaths(path string, allFiles *[]string) {
    files, err := os.ReadDir(path)
    if err != nil {
        slog.Error(err.Error())
        os.Exit(1)
    }

    for _, f := range files {
        realPath := filepath.Join(path, f.Name())
        if f.IsDir() {
            GetAllChartsPaths(realPath, allFiles)
        } else if strings.EqualFold(f.Name(), "Chart.yaml") || strings.EqualFold(f.Name(), "Chart.yml") {
            *allFiles = append(*allFiles, realPath)
        }
    }

}

func ParseChart(filePath string) models.Chart {
    chart, err := os.ReadFile(filePath)
    if err != nil {
        slog.Error(err.Error())
        os.Exit(1)
    }

    var app models.Chart

    err = yaml.Unmarshal(chart, &app)
    if err != nil {
        slog.Error(err.Error())
        os.Exit(1)
    }

    return app
}

