# Azure: Build, Release, Test, Publish (unified pipeline)

## Overview

`.github/workflows/azure-build-release-test-publish.yml` runs the entire
Azure image lifecycle in a single `workflow_dispatch`:

1. **Build** the `.raw` images with Packer (x86_64 + the aarch64 / 64k
   matrix).
2. **Release** each built image to the Azure Compute Gallery — straight
   from the build runner's local `.raw`, with **no S3 round-trip**.
3. **Test** every gallery-released image (boot a VM, assert
   release / arch / RPMs / disk / `dnf`).
4. **Publish** every image that passed its test to the Azure Marketplace
   (draft, optionally submitted to Preview).

It reuses the same composite actions the standalone Azure workflows are
built from, so behaviour matches them stage-for-stage. The standalone
workflows ([azure-build.yml](BUILD_IMAGES.md),
[azure-to-gallery.yml](AZURE_GALLERY.md), [azure-test.yml](AZURE_TEST.md),
[azure-to-marketplace.yml](AZURE_MARKETPLACE.md)) remain available for
running an individual stage or recovering a partial run.

### When to use which

| Use | Workflow |
| :--- | :--- |
| Full release in one dispatch | this unified workflow |
| Just (re)build the `.raw` images | `azure-build.yml` |
| Gallery a VHD/raw that already exists in S3 or Azure | `azure-to-gallery.yml` |
| Test one gallery image version | `azure-test.yml` |
| Publish one VHD blob to Marketplace | `azure-to-marketplace.yml` |

The big win over chaining the standalone workflows by hand is the gallery
stage: the standalone `azure-to-gallery.yml` downloads the `.raw` from S3
(~30 GB) before converting it, whereas here the gallery step converts the
image the build job *just produced* on the same runner — removing two
30 GB transfers per image from the critical path.

## Workflow inputs

| Input | Default | Notes |
| :--- | :--- | :--- |
| `date_time_stamp` | auto (`date -u +%Y%m%d%H%M%S`) | Shared stamp for every matrix leg. |
| `version_major` | `10` | `10-kitten`, `10`, `9`, `8`. |
| `self-hosted` | `true` | If `false`, skip the aarch64 matrix entirely. |
| `upload_to_s3` | `true` | Still uploads to S3 in parallel; the gallery stage no longer depends on it. |
| `release_to_gallery` | `true` | **Master gate** for stages 2-4. `false` = build-only run. |
| `community_gallery` | `true` | Use the Community (public) gallery where eligible. AlmaLinux 10 / Kitten always go to the private `almalinux_ci` gallery (enforced by `tools/azure_uploader.sh`). |
| `release_to_marketplace` | `true` | Publish tested images to Marketplace as drafts. |
| `submit_to_preview` | `false` | Also submit the drafts to Preview / certification. Only honored when `release_to_marketplace` is true. |
| `pungi_repos` | `false` | Build from the PUNGI pre-release repositories instead of `repo.almalinux.org` (see [Building from PUNGI pre-release repositories](#building-from-pungi-pre-release-repositories)). |
| `notify_mattermost` | `true` | Post per-stage notifications to Mattermost. |

There is no `store_as_artifact` input: it was dropped to stay within the
10-input `workflow_dispatch` limit when `pungi_repos` was added, and the
workflow hardcodes it to `false` (no image/checksum artifacts). The ~2 KB
installed-packages `.txt` list is stored as a workflow artifact
unconditionally.

### Stage gating

```
release_to_gallery=false        -> build only (gallery / test / publish skip)
release_to_marketplace=false    -> build + gallery + test (publish skips)
submit_to_preview=true          -> only meaningful with release_to_marketplace=true
```

Test runs for **every** gallery-released image; there is no separate
`run_test` input. Publishing covers exactly the images that **passed**
their test — a failed sibling test does not block the images that passed.

## Job layout

The pipeline is three **independent per-image chains** (no aggregate
"collect" stages):

```
init-data
 ├─ build-x86_64      → test-x86_64      → publish-x86_64
 ├─ start-self-hosted-runner (fork EC2 runners, variant matrix)
 ├─ build-aarch64     → test-aarch64     → publish-aarch64
 └─ build-aarch64-64k → test-aarch64-64k → publish-aarch64-64k
        (9 / 10 / Kitten only)
```

Each build job runs shared-steps, then azure-gallery-steps in-job, which
uploads an `azure-manifest-<variant>-<arch>.json` artifact (VHD blob URL,
created gallery paths, the gen2 test path, and a `marketplace_eligible`
flag). The image's test job downloads that manifest and exposes its
fields as job outputs; the matching publish job is gated on its own
test's success and the `marketplace_eligible` flag.

Why per-image chains: with aggregate collect stages in the middle,
"Re-run failed jobs" on one image's failed build or test re-ran the
collectors and therefore **every** image's test and publish — re-testing
and re-publishing sibling images that had already gone out. With
per-image chains, a re-run walks only the failed image's own downstream
jobs; the manifest artifact survives re-run attempts, so a re-run test
needs no re-build.

The aarch64 and aarch64-64k images share the `almalinux-arm` Marketplace
offer, and parallel Product Ingestion configure calls collide on the
offer's draft revision — their publish jobs are serialised through a
run-scoped `concurrency` group (two jobs at most: one runs, one queues).
The x86_64 publish targets its own offer and runs in parallel.

### Stage composite actions

| Stage | Composite action |
| :--- | :--- |
| Build | [`.github/actions/shared-steps`](.github/actions/shared-steps/action.yml) |
| Gallery | [`.github/actions/azure-gallery-steps`](.github/actions/azure-gallery-steps/action.yml) |
| Test | [`.github/actions/azure-test-steps`](.github/actions/azure-test-steps/action.yml) |
| Publish | [`.github/actions/azure-marketplace-steps`](.github/actions/azure-marketplace-steps/action.yml) |

`azure-test-steps` and `azure-marketplace-steps` are extracted verbatim
from `azure-test.yml` / `azure-to-marketplace.yml` (with `job.status`
replaced by step outcomes so they work inside a composite). `azure-gallery-steps`
is new — it wraps `tools/azure_uploader.sh` and runs it on the local `.raw`.

## Building from PUNGI pre-release repositories

`pungi_repos=true` runs `tools/pungi-repos.sh` before packer, so the images
are built from the PUNGI pre-release compose
(`https://<arch>-pungi-<major>.almalinux.dev`) instead of
`repo.almalinux.org` - the way to validate a new AlmaLinux minor release
before it is published. The script rewrites the boot ISO URLs and the
kickstart `url`/`repo` lines to the per-arch compose hosts; since the
Azure kickstarts preinstall every package the Ansible roles need
(including `WALinuxAgent` and `mdadm`), the whole image content comes from
the compose at anaconda time. An injected `%post` writing
`/etc/yum.repos.d/pungi.repo` (compose BaseOS/AppStream at `priority=1`)
safety-nets any provisioning-time dnf install; a task injected into the
`cleanup_vm` role removes it before the image ships.

The run name gets a `(PUNGI)` suffix, and the build summary and Mattermost
notification carry a `:warning: Built from **PUNGI pre-release
repositories**` note. AlmaLinux 8 (no PUNGI hosts) and Kitten (a rolling
stream - its public repos already ARE the latest compose) ignore the input
and keep building from their public repositories. Images keep their
regular GA-style names.

## Runner sizing

| Job | Runner | Notes |
| :--- | :--- | :--- |
| `build-x86_64` | `r8i.2xlarge` + `nested-virt`, `volume=80g` | x86_64 Packer build + VHD conversion. |
| `build-aarch64` / `build-aarch64-64k` | `a1.metal` or a newer Graviton bare metal (`c6g`/`m6g`/`c7g`/`m7g` `.metal`, `*8gd.metal*`), `volume=80g` (org) / `ec2_root_disk_size_gb: 80` (fork) | aarch64. |

`volume=80g` (vs `40g` for `azure-build.yml`) leaves headroom: the
gallery stage converts the ~30 GB `.raw` to a fixed VHD on the same
volume, roughly doubling the on-disk footprint.

`azure-cli` is preinstalled on the x86_64 `ubuntu24-full-x64` RunsOn
image. On the aarch64 `almalinux-9-aarch64` runner there is no Microsoft
aarch64 RPM, so `azure-gallery-steps` installs it into an isolated venv
(a bare `pip install azure-cli` into the system prefix can resolve
against system site-packages and produce a CLI whose `az storage` module
crashes).

## Marketplace specifics

- **Serialised** (run-scoped `concurrency` group on the two arm publish
  jobs): aarch64 and aarch64-64k share the `almalinux-arm` offer, and
  parallel Product Ingestion `configure` calls collide on the offer's
  draft revision.
- **Kitten aarch64-64k is excluded** from publishing — it has no
  Marketplace plan. The gallery stage flags it `marketplace_eligible:
  false` and `publish-aarch64-64k` skips on that flag.
- Publishing to **Live is always manual** in Partner Center, even after a
  successful Preview submission. See
  [AZURE_MARKETPLACE.md](AZURE_MARKETPLACE.md) for the offer/plan map and
  the two-gate (`release_to_marketplace` → `submit_to_preview`) detail.

## Required GitHub Configuration

### Secrets
| Secret | Description |
|--------|-------------|
| `AZURE_CLIENT_ID` | Azure service principal client ID |
| `AZURE_TENANT_ID` | Azure tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | S3 upload (build stage) |
| `MATTERMOST_WEBHOOK_URL` | Mattermost incoming webhook URL |
| `GIT_HUB_TOKEN` | Packer plugin GitHub API token |
| `EC2_AMI_ID_AL9_AARCH64`, `EC2_SUBNET_ID`, `EC2_SECURITY_GROUP_ID` | fork-only aarch64 EC2 runner |

### Variables (`vars.*`)
| Variable | Description |
|----------|-------------|
| `AWS_REGION`, `AWS_S3_BUCKET` | S3 upload target |
| `MATTERMOST_CHANNEL` | Mattermost channel for notifications |

### Azure RBAC

The service principal needs the gallery-upload rights used by
`tools/azure_uploader.sh` plus the full VM-test RBAC set documented in
[AZURE_TEST.md](AZURE_TEST.md) (note the test stage now also creates and
deletes a per-VM virtual network — `Microsoft.Network/virtualNetworks/{write,delete}`
and `.../subnets/join/action`), plus the Partner Center "Manager" role on
the app registration for the publish stage.

## Troubleshooting

1. **Runner reclaimed mid-run (`The runner has received a shutdown
   signal` / `The operation was canceled`)** — the RunsOn instance came
   up as spot and AWS reclaimed it. The labels are spot-eligible by
   design; if reclaims recur, add `/spot=capacity-optimized` (cheapest
   resilient pool) or `/spot=false` (on-demand) to the `runs-on` label.
2. **`az storage` crashes with `'NoneType' object is not iterable`** —
   a poisoned pip azure-cli on the aarch64 runner. `azure-gallery-steps`
   installs into a venv and runs an `az storage blob list --help` canary
   to fail fast; if a runner has a stale system-prefix install, remove it
   (`sudo pip3 uninstall -y azure-cli azure-cli-core; sudo rm -f /usr/local/bin/az`).
3. **`DeploymentFailed` / `Conflict` or `Subnet ... address prefix
   conflict` in the test stage** — two test legs raced on a shared VNet
   or collided on identical VM names. Already mitigated: each VM is named
   from its (unique) image definition and gets its own VNet/subnet.
4. **Gallery step `Permission denied` copying into `output-*`** — the
   Packer output dir is root-owned; `azure-gallery-steps` chowns it to
   the runner user before the uploader runs.
5. **`Unsupported: version=..., image_type=...` in publish** — the
   offer/plan map in `azure-marketplace-steps` has no entry for that
   combination (e.g. a new major before its offer exists). Add the
   mapping; Kitten aarch64-64k is intentionally excluded earlier.

## See also

- [BUILD_IMAGES.md](BUILD_IMAGES.md) — the build stage (`shared-steps`) in detail.
- [AZURE_GALLERY.md](AZURE_GALLERY.md) — `tools/azure_uploader.sh` and gallery naming.
- [AZURE_TEST.md](AZURE_TEST.md) — gallery-image test assertions and VM lifecycle.
- [AZURE_MARKETPLACE.md](AZURE_MARKETPLACE.md) — Partner Center publish flow and offer/plan map.
