# Build Cloud Images (Azure, GenericCloud, OCI, OpenNebula)

## Overview

This document covers the four per-image-type GitHub Actions workflows that build AlmaLinux OS cloud images with Packer for classic IaaS clouds:

| Workflow | Display name | Image type | Document |
| :--- | :--- | :--- | :--- |
| `.github/workflows/azure-build.yml` | `Azure: Build Image` | `azure` | this file |
| `.github/workflows/gencloud-build.yml` | `GenericCloud: Build Image` | `gencloud`, `gencloud_ext4` | this file |
| `.github/workflows/oci-build.yml` | `OCI: Build Image` | `oci` | this file |
| `.github/workflows/opennebula-build.yml` | `OpenNebula: Build Image` | `opennebula` | this file |

GCP has its own workflow and is documented in [BUILD_GCP.md](BUILD_GCP.md). Vagrant boxes (libvirt, VirtualBox, VMware, Hyper-V) are documented in [BUILD_VAGRANT.md](BUILD_VAGRANT.md). AWS AMIs are documented in [AWS_AMI_BUILD_COPY_RELEASE.md](AWS_AMI_BUILD_COPY_RELEASE.md).

All four workflows share:

- The same `workflow_dispatch` input shape (date stamp, `version_major`, `self-hosted`, artifact/S3/notification toggles).
- The same three-job structure: `init-data` → `build-gh-hosted` (x86_64) → `start-self-hosted-runner` + `build-self-hosted` (aarch64).
- The same composite action `.github/actions/shared-steps/action.yml` that drives the per-variant build / test / upload / notify logic.
- The same `.github/scripts/resolve-image-config.sh` helper that resolves Packer source names, output filenames, and S3 paths.

## Workflow inputs

| Input | Type | Default | Notes |
| :--- | :--- | :--- | :--- |
| `date_time_stamp` | string | auto (`date -u +%Y%m%d%H%M%S`) | Shared timestamp so every matrix leg produces identically dated artifacts. |
| `version_major` | choice | `10` | `10-kitten`, `10`, `9`, `8`. **OCI excludes `10-kitten`.** |
| `self-hosted` | boolean | `true` | If `false`, skip the aarch64 matrix entirely. |
| `store_as_artifact` | boolean | `false` | Upload images as GitHub Actions artifacts. |
| `upload_to_s3` | boolean | `true` | Upload images + checksum + package list to the configured S3 bucket. |
| `notify_mattermost` | boolean | `true` | Post a build summary to Mattermost. |

Triggered manually from the GitHub UI: *Actions → &lt;workflow name&gt; → Run workflow*.

## Image types and variants

| Type | Workflow | Output | x86_64 variants | aarch64 variants |
| :--- | :--- | :--- | :--- | :--- |
| `azure` | `azure-build.yml` | `.raw` (Azure VHD source) | `8`, `9`, `10`, `10-kitten` | `9`, `9-64k`, `10`, `10-64k`, `10-kitten`, `10-kitten-64k` |
| `gencloud` | `gencloud-build.yml` | `.qcow2` (XFS root) | `8`, `9`, `10`, `10-v2`, `10-kitten`, `10-kitten-v2` | `8`, `9`, `10`, `10-kitten` |
| `gencloud_ext4` | `gencloud-build.yml` | `.qcow2` (ext4 root) | `8`, `9`, `10`, `10-v2`, `10-kitten`, `10-kitten-v2` | `8`, `9`, `10`, `10-kitten` |
| `oci` | `oci-build.yml` | `.qcow2` | `8`, `9`, `10` | `8`, `9`, `10` |
| `opennebula` | `opennebula-build.yml` | `.qcow2` | `8`, `9`, `10`, `10-v2`, `10-kitten`, `10-kitten-v2` | `8`, `9`, `10`, `10-kitten` |

Variant-suffix meanings:

- `-v2` — produces an image tagged for the **x86_64_v2** microarchitecture level. x86_64 only; available for AL10 / Kitten 10.
- `-64k` — produces an aarch64 image with a **64 KiB page-size kernel**. Azure only, AL9+.
- `gencloud_ext4` — builds the generic cloud image with an **ext4 root filesystem** instead of the default XFS. Fanned out as a second `subtype` matrix leg alongside `gencloud`.

## Job layout

Every workflow has the same three-job shape (four for `gencloud-build.yml`, where the matrix includes a `subtype` dimension):

```mermaid
graph TD
    A[Trigger Workflow] --> B[init-data<br/>generate date_time_stamp / date_stamp]
    B --> C[build-gh-hosted<br/>x86_64 matrix]
    B --> D{inputs.self-hosted}
    D -->|true| E[start-self-hosted-runner<br/>a1.metal aarch64]
    E --> F[build-self-hosted<br/>aarch64 matrix]
    D -->|false| G[skip aarch64 jobs]
    C --> H[.github/actions/shared-steps]
    F --> H
    H --> I[resolve-image-config.sh<br/>→ packer_source / output_mask / aws_s3_path]
    I --> J[Packer build]
    J --> K[Locate image + SHA-256]
    K --> L[Mount via qemu-nbd + verify<br/>/etc/almalinux-release + arch]
    L --> M{upload_to_s3}
    M -->|Yes| N[Upload image + checksum<br/>+ package list to S3]
    M -->|No| O{store_as_artifact}
    O -->|Yes| P[Upload as GH Artifact]
    N --> Q[Summary + Mattermost]
    P --> Q
```

### `init-data`

Runs on `ubuntu-24.04`. Generates (or passes through) `time_stamp` (YYYYMMDDhhmmss) and `date_stamp` (YYYYMMDD) outputs so every matrix leg lands in the same per-build directory.

### `build-gh-hosted` (x86_64)

Runs on a GitHub-hosted Ubuntu 24.04 runner, or a RunsOn metal instance (`c7i.metal-24xl+c7a.metal-48xl+*8gd.metal*` / `image=ubuntu24-full-x64`) when the repository is under the `AlmaLinux` org. Invokes `./.github/actions/shared-steps` with:

- `type` — workflow's image type (`azure` / `gencloud` / `gencloud_ext4` / `oci` / `opennebula`).
- `variant` — the per-matrix variant from the fan-out, or the raw `version_major` for Azure/OCI (neither of which fans out on x86_64).
- `arch: x86_64`.

### `start-self-hosted-runner` (aarch64)

Runs on `ubuntu-24.04`. Gated by `if: inputs.self-hosted`. When the repository is **not** under the `AlmaLinux` org, uses [`NextChapterSoftware/ec2-action-builder@v1.10`](https://github.com/NextChapterSoftware/ec2-action-builder) to provision an `a1.metal` EC2 instance with `ec2_instance_ttl: 30`, register it as a GitHub runner, and tag it for later cleanup. For AlmaLinux-org runs this job is a no-op; RunsOn provides the aarch64 instance directly.

In `azure-build.yml` the `start-self-hosted-runner` job fans out over the same aarch64 variants (`9`/`9-64k`, `10`/`10-64k`, `10-kitten`/`10-kitten-64k`) so there is one ephemeral runner per variant. The other three workflows start a single runner.

### `build-self-hosted` (aarch64)

Runs on:

- `runs-on={RUN_ID}/family=a1.metal/image=almalinux-9-aarch64` for AlmaLinux-org runs.
- The ephemeral EC2 runner created above (targeted by `github.run_id`) otherwise.

Dispatches a matrix over the aarch64 variants, then calls `./.github/actions/shared-steps` with `arch: aarch64` and the appropriate `type` / `variant` / `subtype`.

## Required GitHub configuration

### Secrets

| Secret | Description |
| :--- | :--- |
| `AWS_ACCESS_KEY_ID` | AWS access key for S3 uploads and EC2 runner provisioning |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key |
| `GIT_HUB_TOKEN` | GitHub PAT for Packer plugins and self-hosted runner registration |
| `MATTERMOST_WEBHOOK_URL` | Mattermost incoming webhook URL |
| `EC2_AMI_ID_AL9_AARCH64` | AMI ID for the aarch64 self-hosted EC2 runner |
| `EC2_SUBNET_ID` | EC2 subnet for self-hosted runners |
| `EC2_SECURITY_GROUP_ID` | EC2 security group for self-hosted runners |

### Variables (`vars.*`)

| Variable | Description |
| :--- | :--- |
| `AWS_REGION` | AWS region for S3 and EC2 |
| `AWS_S3_BUCKET` | S3 bucket for image uploads |
| `MATTERMOST_CHANNEL` | Mattermost channel for notifications |

### Permissions

Every job requests `id-token: write` + `contents: read`. `id-token` is used for Azure OIDC inside the Packer Azure builder and for future Workload Identity Federation hooks; `contents: read` is for the `actions/checkout@v6` step.

## S3 upload layout

Uploads are placed under:

```
s3://{bucket}/images/{version_major}/{release}/{type}/{timestamp}/
```

Examples:

```
s3://almalinux-cloud/images/9/9.6/azure/20260220143000/AlmaLinux-9-Azure-9.6-20260220.x86_64.raw
s3://almalinux-cloud/images/10/10.1/oci/20260220143000/AlmaLinux-10-OCI-10.1-20260220.aarch64.qcow2
s3://almalinux-cloud/images/kitten/10/gencloud_ext4/20260220143000/AlmaLinux-Kitten-GenericCloud-ext4-10-20260220.x86_64.qcow2
```

All uploaded objects are tagged with `public=yes`.

## Image testing

The shared action performs a minimal post-build sanity test for every cloud image (`run_test` is hardcoded to `'false'` for these four workflows, so no Vagrant `vagrant up` is attempted):

1. Load the `nbd` kernel module.
2. Attach the built image using `qemu-nbd` (read-only).
3. Mount the root partition (partition 4 on x86_64, partition 3 on aarch64).
4. Verify `/etc/almalinux-release` matches the expected release string.
5. Verify the `almalinux-release` package architecture.
6. Extract the installed RPM package list (uploaded next to the image).

## Packer source naming

`.github/scripts/resolve-image-config.sh` resolves the Packer source name from `type`, `version`, `arch`, and `variant`:

```
qemu.almalinux-{version}-{type}-{arch}      # AL 8 / 9
qemu.almalinux_{version}_{type}_{arch}      # AL 10 / Kitten 10
```

For Azure x86_64 the legs are named e.g. `qemu.almalinux-8-azure-x86_64`, `qemu.almalinux_10_azure_x86_64`. The `-64k` aarch64 Azure legs follow two different naming conventions depending on the AlmaLinux version:

| Version | 64k Packer source |
| :--- | :--- |
| AL 9 | `qemu.almalinux_9_azure_64k_aarch64` (64k before arch) |
| AL 10 | `qemu.almalinux_10_azure_64k_aarch64` (64k before arch) |
| Kitten 10 | `qemu.almalinux_kitten_10_azure_aarch64_64k` (64k after arch) |

Both conventions are handled by `resolve-image-config.sh`; the Kitten 10 layout is preserved for backward compatibility with the existing Packer templates.

### Packer options by runner OS

The composite action picks different binaries depending on whether the runner is Ubuntu or RHEL-family:

| Runner OS | QEMU binary | OVMF firmware |
| :--- | :--- | :--- |
| Ubuntu | `/usr/bin/qemu-system-{arch}` | `/usr/share/OVMF/OVMF_CODE_4M.fd` |
| RHEL | `/usr/libexec/qemu-kvm` | (default) |

## Troubleshooting

1. **Packer build fails immediately** — confirm the template source exists for the `type`/`variant`/`arch` triple (see the naming rules above). Ensure the runner has `/dev/kvm` accessible and enough free disk (`azure` especially wants ≥30 GiB).
2. **KVM permission denied** — the workflow configures udev rules and adds the runner user to `kvm`; on a truly manual runner you must do this yourself.
3. **Cloud image test fails** — verify the `nbd` module is loadable and that the root partition number matches your arch (4 on x86_64, 3 on aarch64). A failed `/etc/almalinux-release` check usually means Packer reused a stale partial build — clean `output-*/` directories on manual runners.
4. **S3 upload fails** — check that `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` have `s3:PutObject` + `s3:PutObjectTagging` on the bucket and that `AWS_REGION` matches the bucket region.
5. **Self-hosted runner never starts** — verify `EC2_AMI_ID_AL9_AARCH64`, `EC2_SUBNET_ID`, and `EC2_SECURITY_GROUP_ID`; the subnet's AZ must support `a1.metal`. The EC2 runner has a 30-minute TTL, so a long-stalled Packer build will eventually be reaped.

## See also

- [BUILD_GCP.md](BUILD_GCP.md) — GCP image build pipeline.
- [BUILD_VAGRANT.md](BUILD_VAGRANT.md) — Vagrant box build pipelines (libvirt, VirtualBox, VMware, Hyper-V).
- [AWS_AMI_BUILD_COPY_RELEASE.md](AWS_AMI_BUILD_COPY_RELEASE.md) — AWS AMI pipeline.
- Packer documentation: https://developer.hashicorp.com/packer/docs
- AlmaLinux Cloud SIG chat: https://chat.almalinux.org/almalinux/channels/sigcloud
