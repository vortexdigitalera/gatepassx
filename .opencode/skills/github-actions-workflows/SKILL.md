---
name: github-actions-workflows
description: Use when creating, editing, or debugging GitHub Actions workflow files (YAML in .github/workflows/). Covers workflow syntax, triggers (push, pull_request, schedule, workflow_dispatch, etc.), jobs, steps, actions, runners, permissions, concurrency, environments, reusable workflows, expressions, contexts, and filter patterns.
---

# GitHub Actions Workflows

## Components

- **Workflow** — configurable automated process defined in YAML at `.github/workflows/*.yml|yaml`. Runs one or more jobs.
- **Event** — activity that triggers a workflow (push, pull_request, schedule, workflow_dispatch, etc.).
- **Job** — set of steps executed on the same runner. Jobs run in parallel by default; use `needs` for ordering.
- **Step** — individual task: a shell script (`run:`) or an action (`uses:`).
- **Action** — reusable extension (from GitHub Marketplace, a repo path, or a Docker image).
- **Runner** — server that runs a job (GitHub-hosted or self-hosted).

## Workflow structure

```yaml
name: <workflow-name>
run-name: <run-name-with-${{...}}-expressions>

on: <event(s)>          # required — triggers

permissions: <read-all|write-all|{}|map>  # GITHUB_TOKEN scopes

env:                    # shared env vars for all jobs
  KEY: value

defaults:
  run:
    shell: bash
    working-directory: ./

concurrency:            # cancel/queue in-flight runs
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  <job-id>:
    name: <display-name>
    needs: [<job-id>, ...]        # dependencies (omit for parallel)
    if: <condition-expression>
    runs-on: <runner-label>       # e.g. ubuntu-latest, windows-latest, self-hosted
    environment: <env-name>       # with optional deployment protection rules
    concurrency:                  # job-level concurrency
      group: ...
      cancel-in-progress: ...
    permissions: {}               # override workflow-level permissions
    env:                          # job-level env vars
    defaults:
      run:
        shell: pwsh
        working-directory: ./
    strategy:
      matrix:                     # run job N times with different params
        os: [ubuntu-latest, windows-latest]
        node-version: [18, 20]
      fail-fast: true
      max-parallel: 6
    continue-on-error: false
    timeout-minutes: 60
    services:                     # ephemeral containers (Docker)
      redis:
        image: redis
        ports:
          - 6379/tcp
    container:                    # run job inside a container
      image: node:20
      options: --cpus 1
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          ref: ${{ github.head_ref }}

      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}

      - name: Install & Test
        run: |
          npm ci
          npm test
        shell: bash
        working-directory: ./app
        env:
          NODE_ENV: test

      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: build-${{ matrix.os }}
          path: dist/

      - name: Output
        id: output-step
        run: echo "result=success" >> $GITHUB_OUTPUT

    outputs:              # job outputs consumed by downstream jobs
      summary: ${{ steps.output-step.outputs.result }}
```

## Triggers (`on`)

### Single / multiple events

```yaml
on: push
on: [push, pull_request, workflow_dispatch]
```

### Activity types

```yaml
on:
  issues:
    types: [opened, labeled, closed]
  pull_request:
    types: [opened, synchronize, reopened]
```

### Filters — branches, tags, paths

```yaml
on:
  push:
    branches: [main, "releases/**"]
    branches-ignore: ["mona/**"]            # can't mix with branches
    tags: [v1.*, v2]
    tags-ignore: [v1-alpha]
    paths: ["**.js", "!docs/**"]           # include / exclude
    paths-ignore: ["docs/**"]
  pull_request:
    branches: [main]
    paths: ["src/**"]
```

Negation with `!` requires at least one positive pattern. Order matters.

### Schedule (cron)

```yaml
on:
  schedule:
    - cron: "30 5 * * 1-5"                # UTC by default
      timezone: "America/New_York"         # optional IANA tz
```

### Workflow dispatch (manual trigger)

```yaml
on:
  workflow_dispatch:
    inputs:
      environment:
        description: Target environment
        type: environment                  # choice | boolean | number | string | environment
        required: true
        default: staging
      debug:
        type: boolean
        default: false
```

### Workflow call (reusable)

```yaml
on:
  workflow_call:
    inputs:
      username:
        description: A username
        default: john-doe
        required: false
        type: string
    outputs:
      summary:
        description: Build summary
        value: ${{ jobs.build.outputs.result }}
    secrets:
      token:
        description: A token
        required: true
```

### Workflow run (chain workflows)

```yaml
on:
  workflow_run:
    workflows: ["Build"]
    types: [completed, requested]
    branches: [main]
    branches-ignore: [canary]
```

### Other events

`repository_dispatch`, `page_build`, `release`, `deployment`, `status`, `check_run`, `label`, `issue_comment`, `pull_request_review`, `pull_request_target` (runs in context of base branch — careful with untrusted forks), `registry_package`, `watch`, `fork`, `discussion`, `create`, `delete`.

### Triggering workflow from another workflow

`GITHUB_TOKEN` events do NOT trigger new workflow runs (except `workflow_dispatch`, `repository_dispatch`, and `pull_request` with `opened/synchronize/reopened` which require approval). Use a PAT or GitHub App token to trigger workflows recursively.

## Permissions (`GITHUB_TOKEN`)

Set at workflow or job level. Unspecified scopes default to `none`.

```yaml
permissions:
  actions: read
  checks: write
  contents: read
  deployments: none
  id-token: write        # needed for OIDC
  issues: write
  packages: read
  pull-requests: write
  statuses: read
  security-events: read
  discussions: read
  pages: read
```

Shorthands: `permissions: read-all`, `permissions: write-all`, `permissions: {}`.

## Expressions & contexts

Use `${{ <expression> }}` syntax. Available contexts:
- `github` — workflow, repository, event, actor, ref, SHA, etc.
- `env` — environment variables
- `job` — current job info
- `jobs` — outputs from other jobs
- `steps` — outputs from steps
- `runner` — OS, temp dir, etc.
- `secrets` — repository/organization secrets
- `vars` — repository/organization variables
- `inputs` — workflow_dispatch / workflow_call inputs
- `needs` — results of dependency jobs

Functions: `contains`, `startsWith`, `endsWith`, `format`, `join`, `toJSON`, `fromJSON`, `hashFiles`, `success`, `failure`, `always`, `cancelled`.

```yaml
if: ${{ github.event_name == 'pull_request' && github.event.pull_request.user.login != 'dependabot[bot]' }}
```

## Filter pattern cheat sheet

| Pattern | Matches |
|---|---|
| `*` | Any characters except `/` |
| `**` | Any characters including `/` |
| `?` | Any single character |
| `[abc]` | Any character listed |
| `[a-z]` | Range of characters |
| `!` | Negate pattern (must follow a positive match) |
| `\` | Escape special character |

## Environments

Reference an environment (with optional protection rules / required reviewers):

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production
    steps:
      - run: ./deploy.sh
```

## Concurrency

By default multiple jobs within a workflow, multiple workflow runs in a repo, and multiple runs across an owner's account run concurrently. Use `concurrency` to limit parallelism, prevent conflicts (e.g. simultaneous deployments), cancel stale runs (e.g. linters on outdated commits), or queue runs to execute sequentially.

- **Default behavior**: only one run can be pending/active in a concurrency group. Any additional pending run cancels the previous one.
- **Queue mode**: set `cancel-in-progress: false` to let runs wait in line and execute sequentially without cancellation.

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

Common group patterns:
- `${{ github.workflow }}-${{ github.ref }}` — one per branch per workflow
- `${{ github.workflow }}-${{ github.event_name }}` — one per event type
- `deploy-${{ github.ref }}` — one deploy per branch across all workflows

Set `cancel-in-progress: false` to queue runs instead of canceling the previous one.

## Reusable workflows

Call another workflow file:

```yaml
jobs:
  call-workflow:
    uses: octo-org/octo-repo/.github/workflows/reusable.yml@main
    with:
      username: mona
    secrets:
      token: ${{ secrets.MY_TOKEN }}
```

The called workflow must declare `on: workflow_call` with `inputs`, `outputs`, and/or `secrets`.

## Actions

Reference actions from:
- **Marketplace**: `actions/checkout@v4`
- **Same repo**: `./.github/actions/my-action`
- **Docker**: `docker://alpine:3.18`
- **Dockerfile in repo**: `./.github/actions/my-action/Dockerfile`

## Matrix strategy

```yaml
strategy:
  matrix:
    os: [ubuntu-latest, windows-latest]
    node: [18, 20]
    include:
      - os: macos-latest
        node: 20
    exclude:
      - os: windows-latest
        node: 18
  fail-fast: false
  max-parallel: 4
```

## Containers & services

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    container:
      image: node:20
      credentials:
        username: ${{ secrets.DOCKER_USER }}
        password: ${{ secrets.DOCKER_PASS }}
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_PASSWORD: password
        ports:
          - 5432/tcp
      redis:
        image: redis
        ports:
          - 6379/tcp
```

## Caching

```yaml
- name: Cache dependencies
  uses: actions/cache@v4
  with:
    path: ~/.npm
    key: ${{ runner.os }}-npm-${{ hashFiles('**/package-lock.json') }}
    restore-keys: |
      ${{ runner.os }}-npm-
```

## Artifacts

An artifact is a file or collection of files produced during a workflow run. Artifacts persist data after a job completes and share data with other jobs in the same workflow. Common uses: build output, test results/screenshots, log files, code coverage, binary/compressed files.

### Artifacts vs dependency caching

| Artifacts | Caching |
|---|---|
| Save files produced by a job to view after the run | Reuse files that don't change often between jobs/runs |
| Built binaries, build logs, test screenshots | Build dependencies (node_modules, ~/.npm, etc.) |
| Stored per-run, deleted when run is deleted | Reusable across runs via cache keys |

### Usage

```yaml
- uses: actions/upload-artifact@v4
  with:
    name: my-artifact
    path: build/
    if-no-files-found: error
    retention-days: 5

- uses: actions/download-artifact@v4
  with:
    name: my-artifact
    path: ./downloads
```

### Artifact attestations

Artifact attestations create cryptographically signed provenance and integrity guarantees for builds. Each attestation includes:
- Link to the workflow that produced the artifact
- Repository, organization, environment, commit SHA, triggering event
- Information from the OIDC token used to establish provenance
- Optionally, an associated software bill of materials (SBOM)

Attestations appear under the artifact list after a build run. For details, see [Using artifact attestations to establish provenance for builds](https://docs.github.com/en/actions/security-guides/using-artifact-attestations-to-establish-provenance-for-builds).

### Deleted workflow runs

When a workflow run is deleted, all artifacts associated with that run are also deleted. Delete via GitHub Actions UI, REST API (`DELETE /repos/{owner}/{repo}/actions/runs/{run_id}`), or `gh run delete`.

## GitHub Actions built-in env vars

`CI`, `GITHUB_WORKFLOW`, `GITHUB_RUN_ID`, `GITHUB_RUN_NUMBER`, `GITHUB_JOB`, `GITHUB_ACTION`, `GITHUB_ACTOR`, `GITHUB_REPOSITORY`, `GITHUB_EVENT_NAME`, `GITHUB_SHA`, `GITHUB_REF`, `GITHUB_HEAD_REF`, `GITHUB_BASE_REF`, `GITHUB_SERVER_URL`, `GITHUB_API_URL`, `GITHUB_GRAPHQL_URL`, `RUNNER_OS`, `RUNNER_ARCH`, `RUNNER_NAME`.

Set job outputs via `$GITHUB_OUTPUT`, environment variables via `$GITHUB_ENV`, step summaries via `$GITHUB_STEP_SUMMARY`.

## Security notes

- `pull_request_target` runs in the context of the base branch with write access — avoid checking out/executing PR code directly.
- `GITHUB_TOKEN` from forks is read-only unless `Send write tokens` setting is enabled.
- Dependabot-triggered workflows use read-only `GITHUB_TOKEN` and no secret access.
- Pin actions to a full SHA for supply-chain security: `actions/checkout@<full-sha>`.
