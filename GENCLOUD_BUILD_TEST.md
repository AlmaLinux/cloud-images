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
| `s390x` | `true` | Build s390x images under QEMU TCG emulation on an x86_64 self-hosted runner (40 to 90 minutes per run; offline validation only). See [s390x under TCG](#s390x-under-tcg-experimental). |
| `ppc64le` | `true` | Build ppc64le images (`gencloud` and `gencloud_ext4`) under QEMU TCG emulation on an x86_64 self-hosted runner (30 to 50 minutes per image; offline validation only). See [ppc64le under TCG](#ppc64le-under-tcg-experimental). |
| `store_as_artifact` | `false` | Upload images as workflow artifacts. |
| `upload_to_s3` | `true` | Upload to S3 in parallel. The test no longer depends on it; when true, the job summary / Mattermost message link the public S3 URL, otherwise they show the filename only. |
| `notify_mattermost` | `true` | Post per-image build and test notifications to Mattermost. |

There is no `run_test` input: the test always runs.

## Job layout

```
init-data
 |- build-gh-hosted (x86_64 matrix: subtype x variant)   -. shared-steps build,
 |- start-self-hosted-runner (fork EC2)                    | then gencloud-test-steps
 |- build-self-hosted (aarch64 matrix: subtype)          -' in-job on the local qcow2
 |- build-s390x-tcg (s390x, default on)                  -  shared-steps build under
                                                             TCG, offline validation only
 '- build-ppc64le-tcg (default on; ppc64le matrix: subtype) shared-steps build under
                                                            TCG + offline validation only
```

There is no collect / publish stage: because the test runs in-job, each
build matrix leg reports its own build+test result directly. The matrix:

| Job | Arch | Matrix |
| :--- | :--- | :--- |
| `build-gh-hosted` | x86_64 | `subtype` in {`gencloud`, `gencloud_ext4`} x `variant` ({`10`,`10-v2`} for AL10/Kitten, else just the major) |
| `build-self-hosted` | aarch64 | `subtype` in {`gencloud`, `gencloud_ext4`} |
| `build-s390x-tcg` | s390x | `gencloud` only (no ext4 kickstart for s390x); runs only with `s390x=true` |
| `build-ppc64le-tcg` | ppc64le (emulated) | `subtype` in {`gencloud`, `gencloud_ext4`}; on by default, skipped with `ppc64le=false` |

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
| `build-s390x-tcg` | same x86_64 metal family as `build-gh-hosted` (KVM unused - TCG) | `ubuntu-24.04` |
| `build-ppc64le-tcg` | same as `build-gh-hosted` (x86_64 metal; KVM unused, TCG is CPU-bound) | `ubuntu-24.04` |

Both org runners are bare metal, so `/dev/kvm` is present for the in-job
QEMU test. The composite installs `qemu-system-*` + `cloud-image-utils`
via `apt-get`, which is why the aarch64 leg must be on an Ubuntu image.

**Fork caveat:** the fork aarch64 fallback is the EC2 `a1.metal` runner
built from `EC2_AMI_ID_AL9_AARCH64` (AlmaLinux 9). The apt-based test
composite cannot run there, so the in-job aarch64 test step will fail on a
fork. The AlmaLinux-org path (`ubuntu24-full-arm64`) is the target; fork
CI should test aarch64 via the standalone `gencloud-test.yml` on
`ubuntu-24.04-arm`.

## s390x under TCG (experimental)

There are no s390x runners, and KVM cannot accelerate a foreign
architecture, so the s390x GenericCloud image is built on an x86_64 runner
with `qemu-system-s390x` in TCG full-system emulation. Functionally it is
the same install the Jenkins s390x host performs with oz; the price is
speed - about 3x slower than native: 40 to 90 minutes per image depending
on the major (the job allows 12 hours). The leg is on by default, so the
scheduled builds include it; `s390x=false` skips it for a run.

How it differs from the other arches (see the `*_gencloud_s390x` sources in
the templates):

- **Direct kernel boot.** s390x has no BIOS boot menu to type a
  `boot_command` into. shared-steps downloads the installer `kernel.img`
  and `initrd.img` (URLs are template locals, `local.s390x_kernel_url_*`,
  resolved with `packer console` so they follow `os_ver_*` and any URL
  rewrite applied to the templates first) into `s390x-boot/`, and the
  source passes them with
  `-kernel`/`-initrd` plus `inst.ks=` on the kernel command line.
- **No boot ISO.** `s390-ccw-virtio` has no IDE bus for Packer's default
  CD-ROM, so the install target is a blank qcow2 (`disk_image = true`)
  that Packer grows to `disk_size`; anaconda fetches stage2 from the
  kickstart `url`.
- **Kickstart-only, no SSH.** The s390x kickstarts carry the whole
  provisioning in `%post` (no Ansible), so the source uses
  `communicator = "none"` and the Ansible provisioner has an `except` for
  it. The kickstart ends with `reboot`; `-no-reboot` turns that into a QEMU
  exit, which is what Packer waits for (`s390x_install_timeout`, 8h).
- **Diagnostics.** The SCLP console goes to `s390x-boot/console.log`; on a
  failed build shared-steps prints its tail.
- **Validation.** shared-steps' offline checks run (release string, RPM
  arch, package list - root is partition 2: `/boot` + `/`), but there is
  no in-job boot test: `gencloud-test-steps` needs KVM.

Known risk to confirm on the first runs: AlmaLinux 10 targets the z14
instruction set; the source uses `-cpu max` so TCG exposes everything it
implements, but if the installer hits an unimplemented facility the
console log will show it.

## ppc64le under TCG (experimental)

There are no POWER runners, so the `build-ppc64le-tcg` job (on by default,
`ppc64le=false` skips it) builds the ppc64le images on an x86_64 runner with QEMU's Tiny Code Generator
(TCG): the guest CPU is emulated in software, the virtio disk and network
stay paravirtual. It uses the **same Packer sources** Jenkins runs on a
POWER host (boot ISO, GRUB boot command, kickstart, SSH + ansible), switched
to emulation through variables that shared-steps passes on the command line:

| Variable | Jenkins / POWER default | GitHub (TCG) value |
| :--- | :--- | :--- |
| `ppc64le_accelerator` | `none` (KVM-HV comes from the machine type) | `tcg` |
| `ppc64le_machine_type` | `pseries,accel=kvm,kvm-type=HV` | `pseries` |
| `ppc64le_cpu_model` | empty (QEMU default = host CPU) | `POWER9` (EL10 baseline; fully implemented by TCG) |
| `ppc64le_console_log` | empty | `<workspace>/ppc64le-console.log`, streamed into the job log as `[ppc64le console]` lines |
| `ppc64le_extra_kernel_args` | empty | `console=hvc0`, typed at the end of the GRUB boot command. SLOF makes the VGA display the primary console when a VGA adapter exists (Packer needs one for the VNC keyboard), so without it anaconda draws its text UI on the uncaptured VGA console and hvc0 only shows a shell banner |
| `ppc64le_grub_hold` | `false` | `true`: the boot command starts with 30 s of once-a-second keypresses GRUB's menu ignores, then moves up from the ISO's default entry ("Test this media & install", whose `rd.live.check` hashes the 1.5 GB ISO for the better part of an hour under emulation) to the plain "Install" entry before the usual edit sequence. The ISO's GRUB menu auto-boots after only 5 s and appears about 8 s after the VM starts, so typing at one fixed delay is a race (the first runs lost it and installed without the kickstart); the presses stop the countdown as soon as the menu is up. SLOF keeps auto-booting, so the reboot after the install comes up on its own |
| `gencloud_boot_wait_ppc64le` | `8s` | `3s` (start the keypress hold before GRUB can appear) |
| `ssh_timeout` | `3600s` | `4h` (the whole emulated install runs before SSH is up) |

The emulator is **not** Ubuntu 24.04's QEMU 8.2.2: under TCG it miscompiles
POWER9 vector loads/stores, and the EL9/EL10 installer's Python crashes at
"Starting installer" with segfaults or corrupted objects (reproduced on a
test host; [QEMU issue 1769](https://gitlab.com/qemu-project/qemu/-/issues/1769)).
shared-steps builds a small Fedora 43 container image with QEMU 10.x and
installs `/usr/local/bin/qemu-system-ppc64-tcg`, a wrapper that runs
`qemu-system-ppc64` in that container with host networking (Packer's VNC and
SSH-forward ports stay on the host loopback) and the workspace and Packer's
ISO cache mounted at their own paths; Packer gets it as `qemu_binary`. Disk
images are still created by the host's `qemu-img`.

What the job does and does not do:

- Offline validation runs as for every arch (release string, `almalinux-release`
  arch, package list from the RPM database; root is partition 3: PReP boot,
  `/boot`, `/`).
- **No in-job boot test**: `gencloud-test-steps` needs KVM.
- Expect one to a few hours per image. Everything the guest does (SLOF,
  GRUB, anaconda, the ansible provisioning over SSH, the zero-fill of the
  disk) is CPU-emulated; the job timeout is 12 hours.

Tuning notes: SLOF and GRUB draw on the VGA console, so the captured
console shows neither; the kernel's `Command line:` line is the first proof
that the typed arguments (`inst.ks=...`, `console=hvc0`) arrived. If it
lacks them, GRUB booted its default entry: check in the console when SLOF
handed over to GRUB (`Trying to load`) against the 30 s keypress window
that starts after `gencloud_boot_wait_ppc64le`. If the guest dies with an illegal instruction, the CPU
model is too old for the kernel; POWER9 is the minimum for AlmaLinux 10 and
Kitten.

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
