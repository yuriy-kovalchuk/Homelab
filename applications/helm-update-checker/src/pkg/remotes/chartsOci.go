package remotes

import (
    "errors"
    "fmt"
    "github.com/Masterminds/semver/v3"
    "github.com/google/go-containerregistry/pkg/authn"
    "github.com/google/go-containerregistry/pkg/name"
    "github.com/google/go-containerregistry/pkg/v1/remote"
    "log/slog"
    "sort"
    "strings"
    "update-checker/internal/models"
)

func CheckNewChartVersionOci(chart models.Chart) error {

    for _, dependency := range chart.Dependencies {
        baseRepo := strings.TrimPrefix(dependency.Repository, "oci://")

        repository, err := name.NewRepository(baseRepo + "/" + dependency.Name)
        if err != nil {
            return err
        }

        tags, err := remote.List(repository, remote.WithAuth(authn.Anonymous))
        if err != nil {
            return err
        }

        latestVersion, err := getLatestSemVer(tags)
        if err != nil {
            return err
        }

        slog.Info(fmt.Sprintf("For %s found new version: %s -> %s", dependency.Name, dependency.Version, latestVersion))

    }

    return nil
}

func getLatestSemVer(tags []string) (string, error) {

    if len(tags) == 0 {
        return "", errors.New("no tags provided")
    }

    var stableVersions []*semver.Version

    for _, tag := range tags {
        semVer, err := semver.NewVersion(tag)
        if err != nil {
            continue
        }

        if semVer.Prerelease() == "" {
            stableVersions = append(stableVersions, semVer)
        }
    }

    sort.Sort(semver.Collection(stableVersions))

    return stableVersions[len(stableVersions) - 1].String(), nil
}
