package remotes

import (
    "fmt"
    "gopkg.in/yaml.v3"
    "io"
    "log/slog"
    "net/http"
    "update-checker/internal/models"
)

func CheckNewChartVersionHttp(chart models.Chart) error {
    for _, dependency := range chart.Dependencies {
        resp, err := http.Get(dependency.Repository + "/index.yaml")
        if err != nil {
            slog.Error(err.Error())
            return err
        }
        defer func(Body io.ReadCloser) {
            err := Body.Close()
            if err != nil {
                slog.Error(err.Error())
            }
        }(resp.Body)

        body, _ := io.ReadAll(resp.Body)

        var customIndex models.CustomIndex

        err = yaml.Unmarshal(body, &customIndex)
        if err != nil {
            slog.Error(err.Error())
            return err
        }

        versions := customIndex.Entries[dependency.Name]
        if len(versions) > 0 {
            latestVersion := versions[0].Version
            slog.Info(fmt.Sprintf("For %s found new version: %s -> %s", dependency.Name, dependency.Version, latestVersion))
        }
    }

    return nil
}
