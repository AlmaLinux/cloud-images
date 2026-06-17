# OpenNebula: Build and Test (unified pipeline)

## Overview

`.github/workflows/opennebula-build-test.yml` builds the AlmaLinux
OpenNebula `.qcow2` images with Packer and boot-tests each one in a single
`workflow_dispatch`:

1. **Build** the `.qcow2` images with Packer (x86_64 + the `x86_64_v2`
   microarch for AL10 / Kitten + aarch64).
2. **Test** each freshly built image **in-job, on the build runner**,
   under QEMU/KVM with a one-context `CONTEXT` ISO (release / arch /
   one-context contextualization / disk / `dnf` assertions over SSH), with
   no S3 round-trip and no separate test job.

Every built image is tested - there is no per-stage gate. For a
build-only run use the standalone [`opennebula-build.yml`](BUILD_IMAGES.md).

### Why this can run in-job (and the OCI / Azure unified flows can't)

The OpenNebula test boots the image locally under QEMU/KVM, so it needs a
runner with `/dev/kvm` and the apt-based hypervisor packages. The build
runners are already bare-metal-with-KVM; the only change from
`opennebula-build.yml` is that the **aarch64 leg builds on the Ubuntu
arm64 RunsOn image (`ubuntu24-full-arm64`) instead of
`almalinux-9-aarch64`**. That makes both build runners Ubuntu-with-KVM, so
the [`opennebula-test-steps`](.github/actions/opennebula-test-steps/action.yml)
composite runs on the same machine that just produced the qcow2.
`shared-steps`' `runner_os` detection builds happily on Ubuntu for both
arches (the x86_64 leg already does).

### When to use which

| Use | Workflow |
| :--- | :--- |
| Build and test in one dispatch | this unified workflow |
| Just (re)build the `.qcow2` images | `opennebula-build.yml` |
| Test an existing image URL (build's S3 URL or repo.almalinux.org) | `opennebula-test.yml` |

The standalone [`opennebula-test.yml`](OPENNEBULA_TEST.md) downloads an
image from a URL; the unified workflow instead tests the local build
output (`opennebula-test-steps` takes an `image_file` as well as an
`image_url`).

## Workflow inputs

The input set is identical to [`opennebula-build.yml`](BUILD_IMAGES.md):

| Input | Default | Notes |
| :--- | :--- | :--- |
| `date_time_stamp` | auto (`date -u +%Y%m%d%H%M%S`) | Shared stamp for every matrix leg. |
| `version_major` | `10` | `10-kitten`, `10`, `9`, `8`. |
| `self-hosted` | `true` | If `false`, skip the aarch64 build entirely. |
| `store_as_artifact` | `false` | Upload images as workflow artifacts. |
| `upload_to_s3` | `true` | Upload to S3 in parallel. The test no longer depends on it; when true, the job summary / Mattermost message link the public S3 URL, otherwise they show the filename only. |
| `notify_mattermost` | `true` | Post per-image build and test notifications to Mattermost. |

There is no `run_test` input: the test always runs.

## Job layout

```
init-data
 |- build-gh-hosted (x86_64 matrix: variant)   -. shared-steps build,
 |- start-self-hosted-runner (fork EC2)          | then opennebula-test-steps
 '- build-self-hosted (aarch64, no matrix)      -' in-job on the local qcow2
```

There is no collect / publish stage: because the test runs in-job, each
build leg reports its own build+test result directly. OpenNebula has a
single subtype (no `gencloud_ext4`-style split), so the x86_64 job only
fans out on `variant` ({`10`,`10-v2`} for AL10 / Kitten, else just the
major) and the aarch64 job is a single leg.

### Stage composite actions

| Stage | Composite action |
| :--- | :--- |
| Build | [`.github/actions/shared-steps`](.github/actions/shared-steps/action.yml) |
| Test | [`.github/actions/opennebula-test-steps`](.github/actions/opennebula-test-steps/action.yml) |

`opennebula-test-steps` is the same composite the standalone
`opennebula-test.yml` uses. It gained an optional `image_file` input: when
set it tests the locally-built qcow2 (it chowns the root-owned Packer
output and copies it to `base.qcow2`) instead of downloading `image_url`.
The change is backward-compatible - `opennebula-test.yml` keeps passing
`image_url` and is unchanged.

## Runner sizing

| Job | Runner (AlmaLinux org) | Runner (forks) |
| :--- | :--- | :--- |
| `build-gh-hosted` | `c7i.metal-24xl+c7a.metal-48xl+*8gd.metal*`, `image=ubuntu24-full-x64` | `ubuntu-24.04` (GitHub-hosted, has nested `/dev/kvm`) |
| `build-self-hosted` | `a1.metal`, `image=ubuntu24-full-arm64`, `volume=40g` | self-hosted EC2 `a1.metal` (`EC2_AMI_ID_AL9_AARCH64`) |

Both org runners are bare metal, so `/dev/kvm` is present for the in-job
QEMU test. The composite installs `qemu-system-*` + `qemu-utils` +
`genisoimage` via `apt-get`, which is why the aarch64 leg must be on an
Ubuntu image.

**Fork caveat:** the fork aarch64 fallback is the EC2 `a1.metal` runner
built from `EC2_AMI_ID_AL9_AARCH64` (AlmaLinux 9). The apt-based test
composite cannot run there, so the in-job aarch64 test step will fail on a
fork. The AlmaLinux-org path (`ubuntu24-full-arm64`) is the target; fork
CI should test aarch64 via the standalone `opennebula-test.yml` on
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
OpenNebula is the public, direct-download image and the test runs locally
under QEMU/KVM.

## Test assertions

The in-job test runs the same assertions as the standalone
`opennebula-test.yml` (see [OPENNEBULA_TEST.md](OPENNEBULA_TEST.md#test-assertions)
for the full list): AlmaLinux release string, system architecture
(including the `x86_64_v2` microarch suffix), the OpenNebula payload
package set (`one-context`, the release-addons package, growpart/parted,
qemu-guest-agent, etc.), one-context services active, `CONTEXT` ISO
detection, `SET_HOSTNAME` + DHCP contextualization applied, root-FS resize
to >= 95 GiB, and `dnf check-update`.

## Troubleshooting

1. **In-job aarch64 test fails with apt / package errors on a fork** -
   the fork ran aarch64 on the EL9 EC2 runner. Expected; see the fork
   caveat above. Build on `ubuntu24-full-arm64` (org) or test via
   `opennebula-test.yml`.
2. **`/dev/kvm not present`** - the runner lacks nested virt. The org
   metal pools always expose `/dev/kvm`; the GitHub-hosted x64 fallback
   has it too.
3. **Test step `Permission denied` opening the qcow2** - Packer runs
   under sudo, so the build output is root-owned; `opennebula-test-steps`
   chowns its copy before QEMU opens it.
4. **`SSH did not become reachable within 10 minutes`** - one-context did
   not bring up the NIC / sshd; the composite dumps the guest `console.log`
   on failure. A common cause is the `ETH0_MAC` / QEMU NIC MAC mismatch
   (the composite pins both to the same value).

For the QEMU invocation, the `CONTEXT` ISO contents, and the full
assertion rationale, see [OPENNEBULA_TEST.md](OPENNEBULA_TEST.md).

## See also

- [BUILD_IMAGES.md](BUILD_IMAGES.md) - the build stage (`shared-steps`) and the OpenNebula variant matrix.
- [OPENNEBULA_TEST.md](OPENNEBULA_TEST.md) - the QEMU/KVM boot-test composite in full (assertions, one-context `CONTEXT` ISO, runner mapping).
