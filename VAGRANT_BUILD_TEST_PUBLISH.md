# Vagrant: Build, Test and Publish (unified pipeline)

## Overview

`.github/workflows/vagrant-build-test-publish.yml` runs the whole Vagrant
box lifecycle in a single `workflow_dispatch`:

1. **Build** the boxes with Packer (one Packer builder per provider:
   `libvirt`, `virtualbox`, `vmware`, `hyperv`; x86_64, plus the
   `x86_64_v2` microarch for AL10 / Kitten, and the VMware, Parallels and
   VirtualBox aarch64 boxes for 9, 10 and Kitten).
2. **Test** each box with a live `vagrant up` smoke test on the build
   runner (via `shared-steps`, gated by `run_test`). Hyper-V and the
   QEMU-built aarch64 boxes are the exceptions - see below.
3. **Upload** each box to S3 (`upload_to_s3`), and **publish** the boxes
   that passed their test in the AlmaLinux **Vagrant box catalog on S3**
   (`release_to_catalog`), all at once in the `publish-catalog` job - see
   [The Vagrant box catalog](#the-vagrant-box-catalog).

It reuses `shared-steps` for build+test+upload (same as the standalone
[`vagrant-build.yml`](BUILD_VAGRANT.md) / [`hyperv-build.yml`](BUILD_VAGRANT.md)).
The HCP Vagrant Registry it used to publish to stopped accepting new box
versions on 2026-10-01 and shuts down on 2026-12-31; the standalone
[`vagrant-publish.yml`](VAGRANT_CLOUD.md) and its `vagrant-publish-steps`
composite only publish there.

### Hyper-V is build-only (no live test)

A Hyper-V guest can't boot on the Linux runner, so there is no live
`vagrant up` test for it. Hyper-V builds as a `hyperv-x86_64` leg of the
`build-gh-hosted` job (not a separate job): that leg forces
`run_test=false`, so only `shared-steps`' offline validation (checksum +
installed-package list) runs, and the box is then published like the
others.

### VMware aarch64 is built under QEMU (no live test)

No runner can run VMware Fusion guests: GitHub's macOS runners expose no
hypervisor (`kern.hv_support=0`), and the other runners are x86_64. So the
VMware Desktop aarch64 box is built the Hyper-V way, as a `vmware-aarch64`
leg of `build-gh-hosted`, for `vagrant_type` `ALL` or `vagrant_vmware`:

- the `*vmware*aarch64` qemu sources (`almalinux-9-vmware-aarch64`,
  `almalinux_10_vagrant_vmware_qemu_aarch64`,
  `almalinux_kitten_10_vagrant_vmware_qemu_aarch64`) install from the boot
  ISO under QEMU - natively under KVM on the AlmaLinux org's arm64 runner,
  elsewhere under TCG on an x86_64 runner with the same `aarch64_*`
  variables, GRUB keypress hold and captured console as the GenericCloud
  aarch64 TCG build (see [Runner sizing](#runner-sizing)) - and are
  provisioned by `ansible/vagrant.yml` as a VMware box
  (`packer_provider=vmware-iso`: open-vm-tools);
- `tools/raw-to-vagrant-vmware.sh` packs the raw disk into a
  `vmware_desktop` box: a VMX from `tpl/vagrant/vmware/box-aarch64.vmx`
  (EFI, one NVMe disk, no network adapter, 4 vCPUs / 4096 MB like the
  hand-built Fusion boxes), a split sparse VMDK, `metadata.json` with
  `arm64`. The kickstart's generic initramfs (`dracut-config-generic`) boots
  on Fusion's NVMe disk and vmxnet3 NIC;
- the leg forces `run_test=false`: only `shared-steps`' offline validation
  of the raw disk (release, architecture, package list) runs, then the box
  is published like the others. It is excluded for the `-v2` variants and
  for AlmaLinux 8 (no VMware aarch64 box for 8).

### Parallels aarch64 is built under QEMU (no live test)

No runner can run Parallels Desktop guests (they need an Apple silicon Mac),
so the Parallels aarch64 box is built the Hyper-V way, as a
`parallels-aarch64` leg of `build-gh-hosted`, for `vagrant_type` `ALL` or
`vagrant_parallels`:

- the leg first downloads the Parallels Tools ISO
  (`https://almalinux-images.s3.us-east-1.amazonaws.com/tools/parallels/26/prl-tools-lin-arm.iso`),
  which the `parallels-iso` builder would take from Parallels Desktop itself.
  It is Parallels Tools 26.x on purpose: the 27.x shared-folder daemon uses
  FUSE 3, which rejects the `-o big_writes` option the `vagrant-parallels`
  plugin (2.4.9) passes, so `/vagrant` would not mount;
- the `*parallels*aarch64` qemu sources (`almalinux-9-parallels-aarch64`,
  `almalinux_10_vagrant_parallels_qemu_aarch64`,
  `almalinux_kitten_10_vagrant_parallels_qemu_aarch64`) install from the
  boot ISO under QEMU the same way as the VMware aarch64 box (natively on
  the org's arm64 runner, under TCG elsewhere). Packer uploads the Tools
  ISO (`parallels_tools_iso_aarch64`) and `ansible/vagrant.yml` provisions
  the guest as a Parallels box (`packer_provider=parallels-iso`: the
  `parallels_guest` role installs the
  Tools); the installed Tools version is downloaded back for the box
  metadata;
- `tools/raw-to-vagrant-parallels.sh` packs the raw disk into a `parallels`
  box: a `.pvm` with `config.pvs` from `tpl/vagrant/parallels/box-aarch64.pvs`
  (cut from a `parallels-iso` box: EFI, one SATA disk, one virtio network
  adapter, 4 vCPUs / 4096 MB; fresh VM/disk UUIDs and MAC addresses), the
  disk as an expanding Parallels image (`harddisk1.hdd`: `DiskDescriptor.xml`
  and one `.hds`, converted by `qemu-img` and rewritten to the
  `WithoutFreeSpace` layout Parallels Desktop writes), and `metadata.json`
  with `arm64`. Parallels Desktop creates `NVRAM.dat` and `VmInfo.pvi` on the
  first boot. The kickstart's generic initramfs boots on the SATA disk and
  virtio NIC;
- the leg forces `run_test=false`: only `shared-steps`' offline validation
  of the raw disk (release, architecture, package list) runs, then the box
  is published like the others. It is excluded for the `-v2` variants and
  for AlmaLinux 8 (no Parallels aarch64 box for 8).

### VirtualBox aarch64 is built under QEMU (no live test)

VirtualBox 7.1+ runs arm64 guests only on Apple silicon Macs, so no runner
can run them either, and the VirtualBox aarch64 box is built the Parallels
way, as a `virtualbox-aarch64` leg of `build-gh-hosted`, for `vagrant_type`
`ALL` or `vagrant_virtualbox` (the x86_64 VirtualBox box is still built by
VirtualBox itself, as the `vagrant_virtualbox` leg):

- the leg first downloads the VirtualBox Guest Additions ISO
  (`https://download.virtualbox.org/virtualbox/7.2.20/VBoxGuestAdditions_7.2.20.iso`,
  checked against Oracle's `SHA256SUMS`), which the `virtualbox-iso` builder
  would take from the installed VirtualBox. 7.2.20 is the first release whose
  `vboxsf` builds against the EL10 / Kitten 6.12 kernels; its ISO carries the
  arm64 Linux installer (`VBoxLinuxAdditions-arm64.run`);
- the `*virtualbox*aarch64` qemu sources (`almalinux-9-virtualbox-aarch64`,
  `almalinux_10_vagrant_virtualbox_qemu_aarch64`,
  `almalinux_kitten_10_vagrant_virtualbox_qemu_aarch64`) install from the
  boot ISO under QEMU the same way as the Parallels aarch64 box (natively on
  the org's arm64 runner, under TCG elsewhere). Packer uploads the Guest
  Additions ISO (`virtualbox_guest_additions_iso_aarch64`) and
  `ansible/vagrant.yml` provisions the guest as a VirtualBox box
  (`packer_provider=virtualbox-iso`): on aarch64 the `virtualbox_guest_arm64`
  role installs the Guest Additions with the arm64 installer (the
  `ezamriy.vbox_guest` role runs only the x86 one). Under QEMU the installer
  builds the `vboxguest` / `vboxsf` modules but cannot start the services, so
  the role checks the built modules instead of the installer's exit code;
- `tools/raw-to-vagrant-virtualbox.sh` packs the raw disk into a
  `virtualbox` box: `box.ovf` from `tpl/vagrant/virtualbox/box-aarch64.ovf`
  (exported by VirtualBox 7.2 from an ARM VM of its defaults for Red Hat
  9.x / 10.x ARM 64-bit: `ARMv8Virtual` chipset, EFI, one VirtioSCSI disk, a
  virtio NIC on NAT, 2 vCPUs / 2048 MB; fresh VM/disk UUIDs and MAC
  address), the disk as a streamOptimized VMDK (`box-disk001.vmdk`, converted
  by `qemu-img`), a `Vagrantfile` with the base MAC, and `metadata.json`
  with `arm64`. The kickstart's generic initramfs boots on the VirtioSCSI
  disk and virtio NIC, and shim's fallback boot loader
  (`EFI/BOOT/BOOTAA64.EFI`) boots it without saved EFI variables;
- the leg forces `run_test=false`: only `shared-steps`' offline validation
  of the raw disk (release, architecture, package list) runs, then the box
  is published like the others. It is excluded for the `-v2` variants and
  for AlmaLinux 8 (no VirtualBox aarch64 box for 8).

### When to use which

| Use | Workflow |
| :--- | :--- |
| Build + test + publish in one dispatch | this unified workflow |
| Just (re)build boxes (no publish) | `vagrant-build.yml` / `hyperv-build.yml` |
| Publish a box that already exists at a URL | `vagrant-publish.yml` |

## The Vagrant box catalog

HashiCorp retired HCP Vagrant
([deprecation notice](https://developer.hashicorp.com/hcp/docs/vagrant/hcp-vagrant-eol)):
no new box versions since 2026-10-01 ("resource creation is currently
disabled"), end of support on 2026-11-02, shutdown on 2026-12-31. The
`almalinux/*` boxes are served from our own catalog on S3 instead:

- **Catalog:** one Vagrant metadata JSON per box (`almalinux/8`, `9`, `10`,
  `10-x86_64_v2`, `10-kitten`, `10-kitten-x86_64_v2`) at
  `s3://<AWS_S3_BUCKET>/vagrant/almalinux/<box>` (and `<box>.json`), public,
  `Content-Type: application/json`;
  `https://<AWS_S3_BUCKET>.s3.us-east-1.amazonaws.com/vagrant/` is the
  address users set as `VAGRANT_SERVER_URL` (or `config.vm.box_url` to the
  box's file).
- **Boxes:** the `.box` files the build uploads to `images/.../vagrant/`;
  each catalog entry carries its S3 URL and sha256.
- **Seed:** `tools/vagrant_catalog.py` built the whole catalog from a
  snapshot of the HCP registry metadata (the released versions, mapped to
  their S3 copies) plus the releases built after HCP closed (`--extra`);
  since this workflow publishes, the S3 files are the source of truth.

### How a run publishes

1. Each build leg whose box is on S3 and **passed its test** - the
   `vagrant up` test (libvirt, virtualbox, vmware x86_64), or the offline
   validation for the legs without one (hyperv, the aarch64 legs) - records
   the box (file name, S3 key, sha256) as a `catalog-entry-*` artifact. A
   leg whose test failed records nothing, so its box is not published (with
   `run_test=false`, the libvirt / virtualbox / vmware x86_64 boxes are not
   tested and therefore not published either).
2. `publish-catalog` (after all build jobs) runs
   `.github/scripts/vagrant-catalog-add.py`: for each catalog box the
   entries touch, it downloads the current file, adds the new version (or
   updates it - a re-run replaces a provider, never duplicates it) with all
   its providers (`vmware` -> `vmware_desktop`, `x86_64`/`x86_64_v2` ->
   `amd64`, `aarch64` -> `arm64`; `default_architecture` on amd64, or on a
   provider's only architecture), and writes the result.
3. It copies the previous file to
   `vagrant/.history/<time stamp>/almalinux/<box>.json` (private), uploads
   the new `<box>` and `<box>.json` (`application/json`, `max-age=300`,
   tagged `public=yes`), and checks them over HTTPS.

All of a run's boxes go into the catalog at once - legs never race on the
same file, and users never see a version with only some of its providers -
and `publish-catalog` runs in a `vagrant-catalog` concurrency group, so
runs never interleave their updates either (they queue).

Publishing happens only in the AlmaLinux org's `almalinux/cloud-images`
repository: forks and ci-dev upload to the same bucket, and must not change
the production catalog. It needs the CI credentials to have `s3:PutObject`
and `s3:PutObjectTagging` on `<AWS_S3_BUCKET>/vagrant/*`.

### Rolling back

Copy a box's file back from `.history` (the version before a run), then
re-upload it as both names:

```bash
aws s3 cp s3://almalinux-cloud/vagrant/.history/<time stamp>/almalinux/10.json 10.json
for name in 10 10.json; do
  aws s3api put-object --bucket almalinux-cloud --key vagrant/almalinux/${name} --body 10.json \
    --content-type application/json --cache-control 'max-age=300' --tagging 'public=yes'
done
```

## Workflow inputs

The input set is [`vagrant-build.yml`](BUILD_VAGRANT.md)'s plus
`release_to_catalog`.

| Input | Default | Notes |
| :--- | :--- | :--- |
| `date_time_stamp` | auto (`date -u +%Y%m%d%H%M%S`) | Shared stamp for every matrix leg. |
| `version_major` | `10` | `10-kitten`, `10`, `9`, `8`. |
| `vagrant_type` | `ALL` | `ALL`, `vagrant_libvirt`, `vagrant_virtualbox`, `vagrant_vmware`, `vagrant_hyperv`, `vagrant_parallels`. |
| `self-hosted` | `true` | Build the self-hosted providers on a self-hosted runner. |
| `self_hosted_runner` | `aws-ec2` | `self-hosted` (manual) or `aws-ec2`. Routes libvirt/virtualbox to the self-hosted leg when set to `self-hosted`. |
| `run_test` | `true` | Live `vagrant up` test (ignored for the hyperv, vmware-aarch64, parallels-aarch64 and virtualbox-aarch64 legs, which are always build-only). |
| `store_as_artifact` | `false` | Upload boxes as workflow artifacts. |
| `upload_to_s3` | `true` | Upload to S3 in parallel; also used for the publish summary/notification link. |
| `release_to_catalog` | `true` | Publish the tested boxes in the [Vagrant box catalog](#the-vagrant-box-catalog) on S3. Needs `upload_to_s3`; applies in `almalinux/cloud-images` only. On by default, so the scheduled runs publish. |
| `notify_mattermost` | `true` | Post per-box build / publish notifications to Mattermost. |

## Job layout

```
init-data  (computes matrix_gh / matrix_sh from vagrant_type; adds
 |          hyperv-x86_64 to matrix_gh for ALL / vagrant_hyperv,
 |          vmware-aarch64 for ALL / vagrant_vmware, parallels-aarch64
 |          for ALL / vagrant_parallels and virtualbox-aarch64 for ALL /
 |          vagrant_virtualbox, except AlmaLinux 8)
 |
 |- build-gh-hosted (matrix_gh x variant)   -. shared-steps build (+ vagrant up
 |     libvirt / virtualbox / hyperv /        | test, except hyperv and the
 |     vmware- / parallels- / virtualbox-     | aarch64 legs) + S3 upload; a
 |     aarch64                                | tested box is recorded for
 |- start-self-hosted-runner (fork EC2)       | the catalog
 |- build-self-hosted (matrix_sh x variant) -'
 |     vmware
 '- publish-catalog (after all builds; almalinux/cloud-images only, gated by
       release_to_catalog): adds the recorded boxes to the catalog at once
```

Provider routing (matching `vagrant-build.yml`):

| Provider | Job (AlmaLinux org default) | Live test? |
| :--- | :--- | :--- |
| libvirt, virtualbox | `build-gh-hosted` (or `build-self-hosted` if `self_hosted_runner=self-hosted`) | yes |
| vmware | `build-self-hosted` (needs the AL9 AMI) | yes |
| hyperv | `build-gh-hosted` leg | no (build-only) |
| vmware aarch64 | `build-gh-hosted` leg on arm64 under KVM (forks: under QEMU TCG) | no (build-only) |
| parallels aarch64 | `build-gh-hosted` leg on arm64 under KVM (forks: under QEMU TCG) | no (build-only) |
| virtualbox aarch64 | `build-gh-hosted` leg on arm64 under KVM (forks: under QEMU TCG) | no (build-only) |

### Stage implementations

| Stage | Implementation |
| :--- | :--- |
| Build + test + S3 upload | [`.github/actions/shared-steps`](.github/actions/shared-steps/action.yml) |
| Catalog publish | [`.github/scripts/vagrant-catalog-add.py`](.github/scripts/vagrant-catalog-add.py) (uses [`tools/vagrant_catalog.py`](tools/vagrant_catalog.py)'s box-name parsing) |

## Runner sizing

| Job | Runner (AlmaLinux org) | Runner (forks) |
| :--- | :--- | :--- |
| `build-gh-hosted` | `r8i.2xlarge`, `image=ubuntu24-full-x64`, `volume=60g`, `nested-virt`, `spot=false`; the `vmware-aarch64` / `parallels-aarch64` / `virtualbox-aarch64` legs: arm64 `a1.metal` or a newer Graviton bare metal (`c6g`/`m6g`/`c7g`/`m7g` `.metal`, `*8gd.metal*`), `image=ubuntu24-full-arm64`, `volume=60g`, `spot=false` | `ubuntu-24.04` |
| `publish-catalog` | `ubuntu-24.04` | - (not run) |
| `build-self-hosted` | `r8i.2xlarge`, `ami=<AL9 x86_64>`, `volume=60g`, `nested-virt`, `spot=false` | EC2 `c5n.metal` (`EC2_AMI_ID_AL9_X86_64`) or a manual self-hosted runner |

`nested-virt` provides KVM for the Packer build and the `vagrant up` test;
`vmware` needs the AlmaLinux 9 AMI (VMware Workstation), which is why it
lives on the self-hosted leg. **Hyper-V now builds on `build-gh-hosted`'s
`r8i.2xlarge`** rather than the metal family the standalone
`hyperv-build.yml` used - this matches the metal-to-`r8i.2xlarge`
migration the vagrant build already made; KVM is available either way.

The `vmware-aarch64`, `parallels-aarch64` and `virtualbox-aarch64` legs
build on arm64 bare metal (`a1.metal` or a newer Graviton `.metal`,
whichever is free) in the AlmaLinux org, where shared-steps runs QEMU natively under KVM (`-cpu
host`, the runner's own firmware), like the GenericCloud aarch64 build.
Forks have no arm64 runner, so the legs run on GitHub's x86_64 Ubuntu
24.04 like the others, and shared-steps emulates their install under QEMU
TCG on a Neoverse V1 CPU (see [GENCLOUD_BUILD_TEST.md](GENCLOUD_BUILD_TEST.md)).
No AlmaLinux 8 box is built on those legs.

`spot=false` pins the build runners on-demand to avoid spot-reclaim
cancellations mid-build (Vagrant builds are long); drop it or switch to a
spot allocation strategy if cost matters more than reclaim resilience.

## Required GitHub Configuration

### Secrets
| Secret | Description |
|--------|-------------|
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | S3 upload (build stage) and the catalog publish (`s3:PutObject` / `s3:PutObjectTagging` on `<AWS_S3_BUCKET>/vagrant/*` too) |
| `MATTERMOST_WEBHOOK_URL` | Mattermost incoming webhook URL |
| `GIT_HUB_TOKEN` | Packer plugin GitHub API token |
| `EC2_AMI_ID_AL9_X86_64`, `EC2_SUBNET_ID`, `EC2_SECURITY_GROUP_ID` | fork-only self-hosted EC2 runner |

### Variables (`vars.*`)
| Variable | Description |
|----------|-------------|
| `EC2_AMI_ID_AL9_X86_64` | AL9 x86_64 AMI for the org self-hosted (vmware) runner |
| `AWS_REGION`, `AWS_S3_BUCKET` | S3 upload target, and the bucket of the catalog |
| `MATTERMOST_CHANNEL` | Mattermost channel for notifications |

## Troubleshooting

1. **`publish-catalog` fails with `AccessDenied` on `PutObject`** - the
   CI credentials lack `s3:PutObject` / `s3:PutObjectTagging` on
   `<AWS_S3_BUCKET>/vagrant/*`. Nothing was changed; add the permission and
   re-run the job.
2. **Two build legs cancelled mid-build, ~simultaneously** - a run-level
   cancel (UI/API) or, on spot runners, a spot reclaim ("The runner has
   received a shutdown signal"). The build runners use `spot=false` to
   avoid the latter.
3. **`dnf -y remove --oldinstallonly` fails in the build** ("No old
   installonly packages found for removal") - a build-role issue in
   `shared-steps`' ansible, independent of this workflow.
4. **A box is missing from the catalog** - its leg's test failed (or did
   not run), so the leg recorded nothing; see the leg's "Tests ..." status.
   Re-running the workflow for the same version adds it next to the
   providers already published.
5. **`publish-catalog` fails with "the catalog file must exist"** - a new
   catalog box (e.g. a new major) has no file yet: create it with
   `tools/vagrant_catalog.py` and upload it first.

## See also

- [BUILD_VAGRANT.md](BUILD_VAGRANT.md) - the build stage (`shared-steps`), the per-provider Packer builders, and the `vagrant up` inline test.
- [VAGRANT_CLOUD.md](VAGRANT_CLOUD.md) - the standalone HCP publish flow (HCP no longer accepts new versions).
