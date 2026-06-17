# GenericCloud: Build and Test (unified pipeline)

## Overview

`.github/workflows/gencloud-build-test.yml` builds the AlmaLinux
GenericCloud `.qcow2` images with Packer and boot-tests each one in a
single `workflow_dispatch`:

1. **Build** the `.qcow2` images with Packer (x86_64 + the `x86_64_v2`
   microarch for AL10 / Kitten + aarch64; each in both the `gencloud`
   XFS-root and `gencloud_ext4` ext4-root subtypes).
2. **Test** each freshly built image **in-job, on the build runner**,
   under QEMU/KVM with a cloud-init seed (release / arch / RPMs / disk /
   `dnf` assertions over SSH), with no S3 round-trip and no separate test
   job.

Every built image is tested - there is no per-stage gate. For a
build-only run use the standalone [`gencloud-build.yml`](BUILD_IMAGES.md).

### Why this can run in-job (and the OCI / Azure unified flows can't)

The GenericCloud test boots the image locally under QEMU/KVM, so it needs
a runner with `/dev/kvm` and the apt-based hypervisor packages. The build
runners are already bare-metal-with-KVM; the only change from
`gencloud-build.yml` is that the **aarch64 leg builds on the Ubuntu arm64
RunsOn image (`ubuntu24-full-arm64`) instead of `almalinux-9-aarch64`**.
That makes both build runners Ubuntu-with-KVM, so the
[`gencloud-test-steps`](.github/actions/gencloud-test-steps/action.yml)
composite runs on the same machine that just produced the qcow2.
`shared-steps`' `runner_os` detection builds happily on Ubuntu for both
arches (the x86_64 leg already does).

### When to use which

| Use | Workflow |
| :--- | :--- |
| Build and test in one dispatch | this unified workflow |
| Just (re)build the `.qcow2` images | `gencloud-build.yml` |
| Test an existing image URL (build's S3 URL or repo.almalinux.org) | `gencloud-test.yml` |

The standalone [`gencloud-test.yml`](GENCLOUD_TEST.md) downloads an image
from a URL; the unified workflow instead tests the local build output
(`gencloud-test-steps` takes an `image_file` as well as an `image_url`).

## Workflow inputs

The input set is identical to [`gencloud-build.yml`](BUILD_IMAGES.md):

| Input | Default | Notes |
| :--- | :--- | :--- |
| `date_time_stamp` | auto (`date -u +%Y%m%d%H%M%S`) | Shared stamp for every matrix leg. |
| `version_major` | `10` | `10-kitten`, `10`, `9`, `8`. |
| `self-hosted` | `true` | If `false`, skip the aarch64 matrix entirely. |
| `store_as_artifact` | `false` | Upload images as workflow artifacts. |
| `upload_to_s3` | `true` | Upload to S3 in parallel. The test no longer depends on it; when true, the job summary / Mattermost message link the public S3 URL, otherwise they show the filename only. |
| `notify_mattermost` | `true` | Post per-image build and test notifications to Mattermost. |

There is no `run_test` input: the test always runs.

## Job layout

```
init-data
 |- build-gh-hosted (x86_64 matrix: subtype x variant)   -. shared-steps build,
 |- start-self-hosted-runner (fork EC2)                    | then gencloud-test-steps
 '- build-self-hosted (aarch64 matrix: subtype)          -' in-job on the local qcow2
```

There is no collect / publish stage: because the test runs in-job, each
build matrix leg reports its own build+test result directly. The matrix:

| Job | Arch | Matrix |
| :--- | :--- | :--- |
| `build-gh-hosted` | x86_64 | `subtype` in {`gencloud`, `gencloud_ext4`} x `variant` ({`10`,`10-v2`} for AL10/Kitten, else just the major) |
| `build-self-hosted` | aarch64 | `subtype` in {`gencloud`, `gencloud_ext4`} |

### Stage composite actions

| Stage | Composite action |
| :--- | :--- |
| Build | [`.github/actions/shared-steps`](.github/actions/shared-steps/action.yml) |
| Test | [`.github/actions/gencloud-test-steps`](.github/actions/gencloud-test-steps/action.yml) |

`gencloud-test-steps` is the same composite the standalone
`gencloud-test.yml` uses. It gained an optional `image_file` input: when
set it tests the locally-built qcow2 (it chowns the root-owned Packer
output and copies it to `base.qcow2`) instead of downloading `image_url`.
The change is backward-compatible - `gencloud-test.yml` keeps passing
`image_url` and is unchanged.

## Runner sizing

| Job | Runner (AlmaLinux org) | Runner (forks) |
| :--- | :--- | :--- |
| `build-gh-hosted` | `c7i.metal-24xl+c7a.metal-48xl+*8gd.metal*`, `image=ubuntu24-full-x64` | `ubuntu-24.04` (GitHub-hosted, has nested `/dev/kvm`) |
| `build-self-hosted` | `a1.metal`, `image=ubuntu24-full-arm64`, `volume=40g` | self-hosted EC2 `a1.metal` (`EC2_AMI_ID_AL9_AARCH64`) |

Both org runners are bare metal, so `/dev/kvm` is present for the in-job
QEMU test. The composite installs `qemu-system-*` + `cloud-image-utils`
via `apt-get`, which is why the aarch64 leg must be on an Ubuntu image.

**Fork caveat:** the fork aarch64 fallback is the EC2 `a1.metal` runner
built from `EC2_AMI_ID_AL9_AARCH64` (AlmaLinux 9). The apt-based test
composite cannot run there, so the in-job aarch64 test step will fail on a
fork. The AlmaLinux-org path (`ubuntu24-full-arm64`) is the target; fork
CI should test aarch64 via the standalone `gencloud-test.yml` on
`ubuntu-24.04-arm`.

## Required GitHub Configuration

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
| `AWS_REGION`, `AWS_S3_BUCKET` | S3 upload target (also used to build the summary image link) |
| `MATTERMOST_CHANNEL` | Mattermost channel for notifications |

No cloud-provider (Azure / OCI / AWS Marketplace) credentials are needed:
GenericCloud is the public, direct-download image and the test runs
locally under QEMU/KVM.

## Test assertions

The in-job test runs the same assertions as the standalone
`gencloud-test.yml` (see [GENCLOUD_TEST.md](GENCLOUD_TEST.md#test-assertions)
for the full list): AlmaLinux release string, system architecture
(including the `x86_64_v2` microarch suffix), the QEMU/KVM cloud-image
package set, root-FS resize to >= 95 GiB, the `ext4`-root assertion for
the `gencloud_ext4` subtype, and `dnf check-update`.

## Troubleshooting

1. **In-job aarch64 test fails with apt / package errors on a fork** -
   the fork ran aarch64 on the EL9 EC2 runner. Expected; see the fork
   caveat above. Build on `ubuntu24-full-arm64` (org) or test via
   `gencloud-test.yml`.
2. **`/dev/kvm not present`** - the runner lacks nested virt. The org
   metal pools always expose `/dev/kvm`; the GitHub-hosted x64 fallback
   has it too.
3. **Test step `Permission denied` opening the qcow2** - Packer runs
   under sudo, so the build output is root-owned; `gencloud-test-steps`
   chowns its copy before QEMU opens it.
4. **`SSH did not become reachable within 10 minutes`** - cloud-init did
   not bring up sshd; the composite dumps the guest `console.log` on
   failure.

For the QEMU invocation, the cloud-init seed, and the full assertion
rationale, see [GENCLOUD_TEST.md](GENCLOUD_TEST.md).

## See also

- [BUILD_IMAGES.md](BUILD_IMAGES.md) - the build stage (`shared-steps`) and the GenericCloud variant matrix.
- [GENCLOUD_TEST.md](GENCLOUD_TEST.md) - the QEMU/KVM boot-test composite in full (assertions, seed ISO, runner mapping).
