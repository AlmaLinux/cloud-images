# GCP: Build, Test and Publish (unified pipeline)

## Overview

`.github/workflows/gcp-build-test-publish.yml` runs the whole GCP image
lifecycle in a single `workflow_dispatch`:

1. **Build** the images with Packer (x86_64 + aarch64, via
   [`gcp-build-steps`](.github/actions/gcp-build-steps/action.yml)):
   upload to the dev GCS buckets and publish a dev test image.
2. **Test** every built image with Google **cloud-image-tests** (CIT):
   smoke tests on both arches in parallel, then the per-shape matrices.
   Tests always run.
3. **Publish** each arch to the `almalinux-cloud` (prod) project, one arch
   at a time - **automatically when all tests pass**, or **after a manual
   approval** when a test fails (see below).

It reuses the jobs from the standalone GCP workflows
([`gcp-build.yml`](BUILD_GCP.md), [`gcp-test.yml`](GCP_IMAGE_TEST_PUBLISH.md),
[`gcp-publish.yml`](GCP_IMAGE_TEST_PUBLISH.md)), which remain available for
running an individual stage or recovering a partial run.

### Manual approval on test failure (the interactive gate)

Because publishing targets the public prod project, a test failure does
**not** silently block or force the release - it routes to a human:

- **All tests pass** -> the `approve-publish` gate is skipped and
  `publish-gcp` runs automatically.
- **A test fails** -> the `approve-publish` job runs. It is tied to the
  **`gcp-prod-publish` GitHub Environment** (Required reviewers), so the
  run **pauses and waits** for a reviewer to inspect the failure and
  **Approve** (publish proceeds) or **Reject** (publish is skipped). While
  waiting it consumes no runner minutes. `publish-gcp` then runs only if
  all tests passed OR `approve-publish` was approved.

There is no `run_test` / `override_test_failure` input - the human
approval is the decision on failure.

> **Required one-time setup:** create the `gcp-prod-publish` Environment
> (repo **Settings -> Environments**) with **Required reviewers**. Without
> reviewers the environment provides no protection and the gate will not
> actually pause - a failed-test run would publish unreviewed.

### When to use which

| Use | Workflow |
| :--- | :--- |
| Build + test + publish in one dispatch | this unified workflow |
| Just (re)build the images | `gcp-build.yml` |
| Test an existing image | `gcp-test.yml` |
| Publish an existing dev image to prod | `gcp-publish.yml` |

## Workflow inputs

| Input | Default | Notes |
| :--- | :--- | :--- |
| `date_time_stamp` | auto (`date -u +%Y%m%d%H%M%S`) | Shared stamp; its `YYYYMMDD` prefix is the publish `image_datetag`. |
| `version_major` | `10` | `10-kitten`, `10`, `9`, `8`. arch is fixed to **ALL** (both x86_64 and aarch64). |
| `self-hosted` | `true` | Build the aarch64 image on a self-hosted runner. Keep true - the ALL-arch test/publish needs it. |
| `store_as_artifact` | `false` | Upload images as workflow artifacts. |
| `upload_to_s3` | `true` | Upload to S3 in parallel. |
| `cit_git_repo` | `''` | Optional: `owner/repo` of a cloud-image-tests fork to build instead of the prebuilt image. |
| `cit_git_ref` | `''` | Branch/tag/SHA in `cit_git_repo`. Ignored when `cit_git_repo` is empty. |
| `publish_images` | `true` | `false` = build and test only, no publish. |
| `notify_mattermost` | `true` | Post build notifications to Mattermost. |

There is intentionally no `run_test` input: tests always run. (`workflow_dispatch`
allows at most 10 inputs; this workflow uses 9.)

## Job layout

```
init-data (time_stamp + YYYYMMDD date_stamp + dev image_path)
 |- build-gcp-x86_64                       -. gcp-build-steps: build + dev GCS
 |- start-self-hosted-runner (fork EC2)     | upload + dev test image
 '- build-gcp-aarch64                       -'
 |- build-cit (optional, cit_git_repo set)
        |
 test-gcp-initialtest (x86_64 + aarch64 smoke, in parallel)
        |
 test-gcp-pershape-x86_64 / test-gcp-pershape-aarch64  (+ summarize-quota-failures)
        |
 approve-publish  (only if a test failed; gcp-prod-publish environment, required reviewers)
        |
 publish-gcp  (matrix arch, max-parallel: 1 -> almalinux-cloud prod)
```

### Stage gating

```
tests always run.
all tests pass  -> publish runs automatically.
a test fails    -> approve-publish pauses for a reviewer; publish only on Approve.
build fails     -> no publish (the approval gate covers test failures, not build failures).
publish_images=false -> build + test only, no publish.
```

`publish-gcp` runs when `!cancelled() && publish_images && both builds
succeeded && (all tests passed || approve-publish approved)`.

## Runners

- **build-gcp-x86_64** / **build-gcp-aarch64**: RunsOn metal
  (`ubuntu24-full-x64` / `ubuntu24-full-arm64`) in the org; `ubuntu-24.04`
  / self-hosted EC2 on forks.
- **build-cit**: RunsOn `m8azn` (Go compile) when building a CIT fork.
- **test jobs**: `ubuntu-24.04` (smoke, aarch64 per-shape) and a RunsOn
  `almalinux-10-x86_64` runner (x86_64 per-shape). Tests run the real GCP
  VMs via `cit-run-with-retry`.
- **publish-gcp**: `ubuntu-latest`.

## Authentication and required configuration

GCP access is via **Workload Identity Federation (OIDC)** - no GCP keys in
secrets. The relevant jobs declare `permissions: id-token: write`:

- Tests authenticate as the image-testing service account
  (`almalinux-image-testing` project).
- Publish authenticates as the prod-release service account
  (`almalinux-image-release` project).

### Secrets
| Secret | Description |
|--------|-------------|
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | S3 upload (build stage) |
| `MATTERMOST_WEBHOOK_URL` | Mattermost incoming webhook URL |
| `GIT_HUB_TOKEN` | Packer plugin GitHub API token |
| `EC2_AMI_ID_AL9_AARCH64`, `EC2_SUBNET_ID`, `EC2_SECURITY_GROUP_ID` | fork-only aarch64 EC2 runner |

### Variables (`vars.*`)
| Variable | Description |
|----------|-------------|
| `AWS_REGION`, `AWS_S3_BUCKET` | S3 upload target |
| `MATTERMOST_CHANNEL` | Mattermost channel for notifications |

### Environment (required for the approval gate)
- **`gcp-prod-publish`** with **Required reviewers** (repo Settings ->
  Environments). Referenced by the `approve-publish` job.

## Troubleshooting

1. **A failed-test run published without asking** - the `gcp-prod-publish`
   environment has no Required reviewers, so the gate did not pause. Add
   reviewers in repo Settings.
2. **Publish skipped after a test failure** - the reviewer Rejected, or the
   approval timed out (GitHub waits up to 30 days).
3. **aarch64 image missing at test/publish** - `self-hosted` was set false,
   so the aarch64 build was skipped; keep it true for the ALL-arch flow.
4. **`workflow_dispatch` input-limit error from actionlint** - GitHub caps
   `workflow_dispatch` at 10 inputs; this workflow uses 9, so anything new
   needs one removed.

## See also

- [BUILD_GCP.md](BUILD_GCP.md) - the build stage (`gcp-build-steps`), SBOM, dev GCS upload, dev test image.
- [GCP_IMAGE_TEST_PUBLISH.md](GCP_IMAGE_TEST_PUBLISH.md) - the cloud-image-tests shapes/filters and the prod publish flow in detail.
