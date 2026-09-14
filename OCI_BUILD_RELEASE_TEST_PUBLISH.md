# OCI: Build, Release to Compute, Test, Publish to Listings (unified pipeline)

## Overview

`.github/workflows/oci-build-release-test-publish.yml` runs the entire
OCI image lifecycle in a single `workflow_dispatch`:

1. **Build** the `.qcow2` images with Packer (x86_64 + aarch64).
2. **Release to Compute**: create a Compute Custom Image from each built
   image, straight from the build runner's local `.qcow2` with **no S3
   round-trip** (upload to Object Storage, import as a Compute Image,
   configure the capability schema and shape compatibility).
3. **Test** every Compute Image (launch a fresh instance, assert
   release / arch / RPMs / disk / `dnf`).
4. **Publish to Listings**: publish every image that passed its test to
   the OCI Marketplace as a draft listing revision, submitted for publishing.

It reuses the same composite actions the standalone OCI workflows are
built from, so behaviour matches them stage-for-stage. The standalone
workflows ([oci-build.yml](BUILD_IMAGES.md),
[oci-test.yml](OCI_TEST.md),
[oci-marketplace-publish.yml](OCI_MARKETPLACE.md)) remain available for
running an individual stage or recovering a partial run.

### When to use which

| Use | Workflow |
| :--- | :--- |
| Full release in one dispatch | this unified workflow |
| Just (re)build the `.qcow2` images | `oci-build.yml` |
| Import a qcow2 / resolve an existing image to a Compute Image | `oci-marketplace-publish.yml` (phase 1, `release_to_marketplace=false`) |
| Test one Compute Image OCID | `oci-test.yml` |
| Publish an existing Compute Image to Marketplace | `oci-marketplace-publish.yml` (phase 2, `release_to_marketplace=true`) |

The big win over chaining the standalone workflows by hand is that the
standalone `oci-marketplace-publish.yml` runs **twice** per image (phase 1
to import, phase 2 to publish) and re-downloads the qcow2 from a URL,
whereas here the compute-image stage imports the image the build job
*just produced* on the same runner - no separate import dispatch and no
qcow2 re-download.

## Workflow inputs

| Input | Default | Notes |
| :--- | :--- | :--- |
| `date_time_stamp` | auto (`date -u +%Y%m%d%H%M%S`) | Shared stamp for every matrix leg. |
| `version_major` | `10` | `10`, `9`, `8`. **OCI has no `10-kitten`.** |
| `self-hosted` | `true` | If `false`, skip the aarch64 build entirely. |
| `store_as_artifact` | `false` | Upload images as workflow artifacts. |
| `upload_to_s3` | `true` | Still uploads to S3 in parallel; the compute-image stage no longer depends on it. |
| `create_compute_image` | `true` | **Master gate** for stages 2-4. `false` = build-only run. |
| `release_to_marketplace` | `true` | Release the image to the Marketplace listing (draft revision, submitted for publishing). |
| `notify_mattermost` | `true` | Post per-stage notifications to Mattermost. |

### Stage gating

```
create_compute_image=false      -> build only (compute-image / test / publish skip)
release_to_marketplace=false    -> build + compute-image + test (publish skips)
```

Test runs for **every** Compute Image; there is no separate `run_test`
input. Publishing covers exactly the images that **passed** their test -
a failed sibling test does not block the images that passed.

## Job layout

The pipeline is two **independent per-image chains** (no aggregate
"collect" stages):

```
init-data
 |- build-x86_64  -> test-x86_64  -> publish-x86_64
 |- start-self-hosted-runner (fork EC2 runner)
 '- build-aarch64 -> test-aarch64 -> publish-aarch64
```

Each build job runs shared-steps, then oci-compute-image-steps in-job,
which uploads an `oci-manifest-<arch>.json` artifact (Compute Image OCID,
custom image name, Object Storage path, and the parsed AlmaLinux
major / version / date / release / code-name / display-arch). The image's
test job downloads that manifest and exposes its fields as job outputs;
the matching publish job is gated on its own test's success and takes
everything the Marketplace stage needs from those outputs.

Why per-image chains: with aggregate collect stages in the middle,
"Re-run failed jobs" on one image's failed build or test re-ran the
collectors and therefore **every** image's test and publish — re-testing
and re-publishing the sibling image that had already gone out. With
per-image chains, a re-run walks only the failed image's own downstream
jobs; the manifest artifact survives re-run attempts, so a re-run test
needs no re-build.

The two publish jobs run in parallel: each arch has its own Marketplace
listing ("AlmaLinux OS <major> (<arch>)"), so draft revisions never
collide.

### Stage composite actions

| Stage | Composite action |
| :--- | :--- |
| Build | [`.github/actions/shared-steps`](.github/actions/shared-steps/action.yml) |
| Release to Compute | [`.github/actions/oci-compute-image-steps`](.github/actions/oci-compute-image-steps/action.yml) |
| Test | [`.github/actions/oci-test-steps`](.github/actions/oci-test-steps/action.yml) |
| Publish to Listings | [`.github/actions/oci-marketplace-steps`](.github/actions/oci-marketplace-steps/action.yml) |

`oci-test-steps` and `oci-marketplace-steps` are extracted from
`oci-test.yml` / `oci-marketplace-publish.yml` (with `secrets`/`vars`
passed as inputs and `job.status` replaced by step outcomes so they work
inside a composite). `oci-compute-image-steps` is new - it wraps the
Object Storage upload + Compute Image import + capability schema + shape
compatibility steps and runs them on the local `.qcow2`.

## Runner sizing

| Job | Runner | Notes |
| :--- | :--- | :--- |
| `build-x86_64` | `c7i.metal-24xl+c7a.metal-48xl+*8gd.metal*`, `image=ubuntu24-full-x64` | x86_64 Packer build + compute-image import. |
| `build-aarch64` | `a1.metal`, `image=almalinux-9-aarch64`, `volume=40g` (org) / `ec2_root_disk_size_gb: 16` (fork) | aarch64. |

The OCI compute-image stage **uploads** the qcow2 to Object Storage and
imports it server-side, so unlike the Azure gallery stage it does not
convert the image on the runner - the build's default disk sizing is
enough (no `volume=80g` bump needed).

The OCI CLI is installed per-job by `install.sh --accept-all-defaults`
(python-based, works on both the Ubuntu x86_64 and AlmaLinux 9 aarch64
build runners). The compute-image step's package install tries `apt-get`
first and falls back to `dnf` so it works on the EL9 aarch64 runner.

## Marketplace specifics

- **Parallel** publish: each architecture publishes to its own listing
  (`AlmaLinux OS <major> (x86_64)` / `AlmaLinux OS <major> (AArch64)`), so
  the per-arch draft revisions never collide - no `max-parallel` needed
  (this is the key difference from the Azure unified workflow, where
  aarch64 and aarch64-64k share one offer and must serialise).
- The aarch64 + major-10 listing is matched as `AArch64/ARM64`.
- The workflow submits the draft revision for publishing: the new package
  lands in the **Publish in Progress** stage and Oracle carries it to Live -
  no manual action in the Console is required. Publishing the new revision
  automatically unpublishes the previous one. See
  [OCI_MARKETPLACE.md](OCI_MARKETPLACE.md) for the listing / terms /
  artifact flow in detail.

## Required GitHub Configuration

### Secrets
| Secret | Description |
|--------|-------------|
| `OCI_CLI_USER` | OCI CLI user OCID |
| `OCI_CLI_TENANCY` | OCI CLI tenancy OCID |
| `OCI_CLI_FINGERPRINT` | OCI CLI API key fingerprint |
| `OCI_CLI_KEY_CONTENT` | OCI CLI API private key (PEM) |
| `OCI_COMPARTMENT_ID` | OCI compartment OCID |
| `OCI_SUBNET_ID` | Public subnet OCID for the test instance (test stage) |
| `OCI_OBJECT_STORAGE_NAMESPACE` | Object Storage namespace (compute-image stage) |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | S3 upload (build stage) |
| `MATTERMOST_WEBHOOK_URL` | Mattermost incoming webhook URL |
| `GIT_HUB_TOKEN` | Packer plugin GitHub API token |
| `EC2_AMI_ID_AL9_AARCH64`, `EC2_SUBNET_ID`, `EC2_SECURITY_GROUP_ID` | fork-only aarch64 EC2 runner |

### Variables (`vars.*`)
| Variable | Description |
|----------|-------------|
| `OCI_CLI_REGION` | OCI region (e.g. `us-ashburn-1`) |
| `OCI_OBJECT_STORAGE_BUCKET` | Object Storage bucket for the imported qcow2 |
| `AWS_REGION`, `AWS_S3_BUCKET` | S3 upload target |
| `MATTERMOST_CHANNEL` | Mattermost channel for notifications |

### OCI IAM

The API key user needs the rights used across the stages: Object Storage
`put`/`head` in the bucket, Compute image import / capability-schema /
shape-compatibility, instance launch + terminate and VNIC/subnet read for
the test, and the `marketplace-publisher` rights (artifact, term, listing,
listing-revision, package) for the publish.

## Troubleshooting

1. **`instance terminate` fails with `Invalid value for
   '--wait-for-state': invalid choice: TERMINATED`** - a newer OCI CLI
   returns a work request from `instance terminate`, so `--wait-for-state`
   wants a work-request state (`SUCCEEDED`), not the instance lifecycle
   state `TERMINATED`. Already fixed in `oci-test-steps` (and the
   standalone `oci-test.yml`).
2. **Compute-image step `Permission denied` reading the qcow2** - Packer
   runs under sudo, so the output dir is root-owned; `oci-compute-image-steps`
   chowns it to the runner user before reading.
3. **`oci: command not found` on the aarch64 build runner** - the CLI is
   installed into `$HOME/bin`; the step adds it to `$GITHUB_PATH`. The
   package prerequisites (`jq`, `file`) install via `apt-get` with a `dnf`
   fallback for the EL9 runner.
4. **Compute image import times out** - the import polls to `AVAILABLE`
   for up to 30 minutes; a stuck import usually means a bad source qcow2
   or an Object Storage path mismatch (check the `OBJECT_NAME` echoed by
   the upload step).
5. **`Unsupported AlmaLinux version`** - the version-to-code-name map in
   `oci-compute-image-steps` / `oci-marketplace-steps` has no entry for
   that version (e.g. a new minor before its code name is added). Add the
   mapping; it is maintained alongside the minor-version bump.

## See also

- [BUILD_IMAGES.md](BUILD_IMAGES.md) - the build stage (`shared-steps`) in detail.
- [OCI_TEST.md](OCI_TEST.md) - Compute Image test assertions and instance lifecycle.
- [OCI_MARKETPLACE.md](OCI_MARKETPLACE.md) - the OCI Marketplace import / publish flow and listing map.
