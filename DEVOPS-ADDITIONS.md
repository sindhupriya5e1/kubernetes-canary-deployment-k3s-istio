# DevOps additions

This branch adds a container CI workflow and an optional Helm chart.

## GitHub Actions + GHCR

The workflow at `.github/workflows/container-ci.yml` builds both stable and canary images on pull requests. On pushes to `main` and manual workflow runs, it also publishes:
- `ghcr.io/<owner>/<repository>:stable`
- `ghcr.io/<owner>/<repository>:canary`

It uses the repository's built-in `GITHUB_TOKEN`; no personal access token is required. Check **Actions** after merging. If package publishing is blocked by repository policy, review Actions permissions and package access settings.

## Helm chart

Validate and render the chart from the repository root:

```bash
helm lint ./helm/canary-demo
helm template canary-demo ./helm/canary-demo
```

Install into a cluster:

```bash
helm upgrade --install canary-demo ./helm/canary-demo --create-namespace
```

The chart creates stable/canary Deployments and Services with the same `app: canary-demo` and `version: stable|canary` labels used by the existing Istio routing resources. By default it uses local image tags `canary-demo:stable` and `canary-demo:canary`. For GHCR images, override the repository and tags, for example:

```bash
helm upgrade --install canary-demo ./helm/canary-demo \
  --set image.repository=ghcr.io/OWNER/REPOSITORY \
  --set stable.tag=stable \
  --set canary.tag=canary
``

Replace OWNER/REPOSITORY with the lowercase GitHub owner/repository path. Ensure the cluster can pull the images if the package is private.

## Important status

These additions are committed on a feature branch and should be merged through the pull request. They have not been run against your laptop's K3s/Istio cluster, so validate the Actions run, Helm lint/template output, and live traffic before describing the enhancements as tested. The workflow publishes images; it does not automatically deploy into a personal cluster or implement metrics-triggered rollback.
