package pkg

import (
    "fmt"
    "log/slog"
    "strings"
    "update-checker/internal/models"
    "update-checker/pkg/remotes"
)

func CheckNewChartVersion(chart models.Chart) {
    for _, dependency := range chart.Dependencies {
        if dependency.Repository != "" {
            switch {

            case strings.HasPrefix(dependency.Repository, "https://"):
                {
                    err := remotes.CheckNewChartVersionHttp(chart)
                    if err != nil {
                        slog.Error(err.Error())
                    }
                }

            case strings.HasPrefix(dependency.Repository, "oci://"):
                {
                    err := remotes.CheckNewChartVersionOci(chart)
                    if err != nil {
                        slog.Error(err.Error())
                    }
                }

            default:
                {
                    slog.Info(fmt.Sprintf("Unsupported Protocol: %s", dependency.Repository))
                }
            }
        }

    }
}
