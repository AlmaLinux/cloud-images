# Scheduled image builds (central dispatcher)

## Overview

`.github/workflows/scheduled-builds.yml` is the **only** workflow with an
`on.schedule` trigger. When one of its crons fires, it converts the firing
into a real `workflow_dispatch` of the target unified workflow via
`gh workflow run`, passing `version_major` as a genuine input. All other
inputs take their `workflow_dispatch` defaults automatically, so the build
workflows carry **no schedule handling and no input emulation**, and their
version-aware `run-name` works natively for scheduled runs.

> **A scheduled firing is a real release cycle.** Dispatching with defaults
> runs the FULL pipeline, publishing included: AWS releases AMIs to all
> regions + Marketplace + a wiki PR, Vagrant publishes boxes to HCP, Azure
> releases to the Compute Gallery and creates Marketplace drafts, OCI
> creates a Compute Image and submits a Marketplace draft for review
> (Azure/OCI Live publishing stays manual). Tests gate publishing inside
> each workflow. `gcp-build-test-publish.yml` is deliberately NOT
> scheduled.

## The schedule

Weekly, Mondays (UTC), one image type per firing, 2 hours apart so the
types do not request metal runners at the same time. Minute 17 avoids
GitHub's congested top-of-the-hour cron slot.

| Cron (UTC) | TYPES[i] | Target workflow |
| :--- | :--- | :--- |
| `17 2 * * 1` | 0 | `opennebula-build-test.yml` |
| `17 4 * * 1` | 1 | `gencloud-build-test.yml` |
| `17 6 * * 1` | 2 | `aws-build-test-copy-release.yml` |
| `17 8 * * 1` | 3 | `azure-build-release-test-publish.yml` |
| `17 10 * * 1` | 4 | `oci-build-release-test-publish.yml` |
| `17 12 * * 1` | 5 | `vagrant-build-test-publish.yml` |

The image type is derived **arithmetically** from the firing cron's hour
field - `type index = (hour - 2) / 2` into the `TYPES` list - so there is
no per-entry cron-to-type map to maintain; the guards fail loudly if a
cron's hour does not fit the scheme.

## Version selection: stateless rotation

The version to build is a pure function of time - weeks since the Unix
epoch modulo the `VERSIONS` list:

```bash
VERSIONS=(8 9 10 10-kitten)
idx=$(( ($(date -u +%s) / 604800) % ${#VERSIONS[@]} ))
```

Every version builds every 4 weeks (~monthly), with no day-of-month
coupling and no stored state. The week index increments Thursdays
00:00 UTC (the epoch started on a Thursday), so Monday firings are never
near the boundary. All image types build the **same version** in a given
week.

### Per-workflow version quirks (handled in the dispatch loop)

- `aws-build-test-copy-release.yml` spells the Kitten choice `kitten_10`
  (not `10-kitten`) - the dispatcher translates.
- `oci-build-release-test-publish.yml` has **no Kitten option** - on
  Kitten weeks the OCI dispatch is skipped (noted in the job summary).

## Where scheduled runs fire

Scheduled firings run only in the AlmaLinux org's
`almalinux/cloud-images` repository (an `if` guard on the dispatch job);
forks and mirrors skip them. GitHub runs `schedule` triggers **only from
the default branch**, so changes take effect once merged to `main`. Note
GitHub cron is not punctual - firings can arrive tens of minutes late,
but the 2-hour type stagger absorbs that.

## Manual runs (testing)

The dispatcher itself also has `workflow_dispatch` (allowed on any repo,
e.g. a CI fork):

| Input | Default | Meaning |
| :--- | :--- | :--- |
| `target_workflow` | `ALL` | One workflow, or `ALL` scheduled types. |
| `version_major` | `rotation` | `rotation` = what this week's schedule would build; or force `10-kitten` / `10` / `9` / `8`. |

Manual runs dispatch on the **current ref**, so running the dispatcher
from a branch exercises that branch's build workflows.

## Extending

- **Add an AlmaLinux major:** append it to `VERSIONS` in the dispatch step
  - the rotation cycle stretches automatically (5 entries = every 5
  weeks).
- **Add an image type:** add a cron at the next even hour AND append the
  workflow to `TYPES` (positions must correspond); optionally add it to
  the `target_workflow` choice list. Check the new workflow's
  `version_major` choices first - token differences or missing versions
  need a case in the dispatch loop (see the AWS/OCI quirks above).

## See also

The unified per-type pipelines this dispatcher schedules:
[AWS](AWS_BUILD_TEST_COPY_RELEASE.md),
[Azure](AZURE_BUILD_RELEASE_TEST_PUBLISH.md),
[OCI](OCI_BUILD_RELEASE_TEST_PUBLISH.md),
[GenericCloud](GENCLOUD_BUILD_TEST.md),
[OpenNebula](OPENNEBULA_BUILD_TEST.md),
[Vagrant](VAGRANT_BUILD_TEST_PUBLISH.md),
[GCP - not scheduled](GCP_BUILD_TEST_PUBLISH.md).
