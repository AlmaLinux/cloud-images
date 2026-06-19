# AWS: Build, Test, Copy to regions and Release (unified pipeline)

## Overview

`.github/workflows/aws-build-test-copy-release.yml` runs the entire AWS
AMI lifecycle in a single `workflow_dispatch`, chaining the three
standalone AWS workflows:

1. **Build** the AMIs with Packer (x86_64 + aarch64) via the EBS-surrogate
   strategy, grant launch permission to the AlmaLinux infra account.
2. **Test** each built AMI (launch an instance from it, assert
   release / arch / `dnf check-update`).
3. **Copy** each AMI to all AWS regions, make it public, and generate the
   wiki CSV/MD data; then open **one** pull request to `almalinux/wiki`.
4. **Release** each AMI to its architecture-specific AWS Marketplace
   product.

It transcribes the jobs from the standalone workflows
([`ami-build.yml`](AWS_AMI_BUILD_COPY_RELEASE.md),
[`ami-copy.yml`](AWS_AMI_BUILD_COPY_RELEASE.md),
[`ami-to-marketplace.yml`](AWS_AMI_BUILD_COPY_RELEASE.md)), which remain
available for running an individual stage or recovering a partial run.

### One wiki PR, never two

The per-arch matrix lives only on `copy-ami` (region copy + per-arch data
generation). The wiki pull request is opened by **`prepare-data-for-wiki`,
a single non-matrix job** that runs once after both arches, merges the
x86_64 + aarch64 data into one MD/CSV, commits one branch, and runs
`gh pr create` exactly once. The two architectures never race to create
conflicting PRs.

### When to use which

| Use | Workflow |
| :--- | :--- |
| Full release in one dispatch | this unified workflow |
| Just (re)build the AMIs | `ami-build.yml` |
| Copy an existing AMI to regions / open the wiki PR | `ami-copy.yml` |
| Release an existing AMI to Marketplace (incl. dev product / draft PR) | `ami-to-marketplace.yml` |

The standalone workflows keep the escape hatches this unified workflow
intentionally hides - the `prod-t4oyq2p42jn2u` dev Marketplace product
(`public_product=false`) and the draft wiki PR (`draft=true`) - so use
them for dry runs / testing.

## Workflow inputs

| Input | Default | Notes |
| :--- | :--- | :--- |
| `version_major` | `10` | `kitten_10`, `10`, `9`, `8`. |
| `notify_mattermost` | `true` | Post per-stage notifications to Mattermost. |

Everything else from the standalone workflows is omitted and acts as a
fixed value:

| Omitted input | Acts as | Effect |
| :--- | :--- | :--- |
| `test_ami` | `true` | The test stage always runs. |
| `make_public` | `true` | AMIs are always copied to all regions and made public. |
| `draft` | `false` | The wiki PR is a normal (non-draft) PR. |
| `release_to_marketplace` | `true` | The Marketplace change set is always submitted. |
| `public_product` | `true` | Always releases to the real public product (never the dev `prod-t4oyq2p42jn2u`). |

## Job layout

```
build-ami (matrix variant x arch)         -> ami_x86_64 / ami_aarch64 outputs
   |
test-ami (matrix arch)                     -> launch + assert per arch
   |
copy-ami (matrix over the 2 AMI IDs)       -> copy to all regions, make public,
   |                                          per-arch wiki data artifact
prepare-data-for-wiki (single job)         -> merge both arches -> ONE wiki PR
   |
release-ami-to-marketplace (matrix 2 AMIs) -> release each to its product
```

### Stage gating

Stages are chained on job results (no extra gating inputs):

```
build-ami fails        -> nothing downstream runs
a test-ami leg fails   -> copy + wiki + release are skipped
copy-ami fails         -> release is skipped
```

The gates use `!cancelled() && needs.<job>.result == 'success'`, so a
failed test leg keeps a broken AMI out of the regions, the wiki, and the
Marketplace.

**All-or-nothing across arches.** The wiki merge needs *both* arches'
data, and the gates key on the whole `test-ami` / `copy-ami` job result -
so if one architecture's test fails, copy / wiki / release are skipped for
*both*. This is stricter than the per-arch "passing legs proceed" model of
the OCI / Azure unified workflows, and is deliberate: the single wiki PR
cannot be assembled from one architecture alone.

## Required GitHub Configuration

### Secrets
| Secret | Description |
|--------|-------------|
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | AWS credentials (build / copy / marketplace) |
| `GIT_HUB_TOKEN` | Packer plugin API token **and** the token used to push the wiki branch + open the PR against `almalinux/wiki` |
| `MATTERMOST_WEBHOOK_URL` | Mattermost incoming webhook URL |

### Variables (`vars.*`)
| Variable | Description |
|----------|-------------|
| `AWS_REGION` | Build / source region (also the region the test instance and AMI-ID grep use) |
| `MATTERMOST_CHANNEL` | Mattermost channel for notifications |

### Fixed AWS identifiers (workflow `env`)
- `ALMALINUX_AWS_ACCOUNT_ID` (`764336703387`) - owner of the source AMIs; the Marketplace access role lives here too.
- `ALMALINUX_AWS_INFRA_ACCOUNT_ID` (`383541928683`) - granted launch permission on each built AMI.
- `wiki_repo` (`almalinux/wiki`) - the PR target.

The Marketplace product IDs (per major / arch, plus the Kitten products)
are hardcoded in the `Get corresponded Product ID` step, mirroring
`ami-to-marketplace.yml`; a new major needs an entry added there.

## Runners

- `build-ami`, `copy-ami`, `prepare-data-for-wiki`, `release-ami-to-marketplace`: `ubuntu-24.04` (GitHub-hosted).
- `test-ami`: a RunsOn instance launched **from the just-built AMI**
  (`t3.medium` for x86_64, `t4g.medium` for aarch64) in `AWS_REGION`, so
  the assertions run on the real image.

## Troubleshooting

1. **`Get AMI ID` step finds nothing** - the AMI ID is grepped from the
   build log by `AWS_REGION: ami-`; a region mismatch or a failed Packer
   build leaves it empty and fails the leg.
2. **`Unsupported AlmaLinux release` in the Marketplace stage** - the
   `Get corresponded Product ID` case has no entry for that major / arch.
   Add the product ID (same list as `ami-to-marketplace.yml`).
3. **Wiki PR step fails on auth** - `GIT_HUB_TOKEN` must have rights to
   push a branch and open a PR on `almalinux/wiki`.
4. **Copy / wiki / release skipped though the build looks fine** - a
   `test-ami` leg failed (or was cancelled). Check both arch test legs;
   the gate is all-or-nothing across arches.

## See also

- [AWS_AMI_BUILD_COPY_RELEASE.md](AWS_AMI_BUILD_COPY_RELEASE.md) - the three standalone workflows in full (build strategy, `tools/aws_ami_mirror.py`, the wiki merge, the Marketplace change set), and the dev-product / draft-PR options this unified workflow omits.
