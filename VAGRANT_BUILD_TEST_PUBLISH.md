# Vagrant: Build, Test and Publish (unified pipeline)

## Overview

`.github/workflows/vagrant-build-test-publish.yml` runs the whole Vagrant
box lifecycle in a single `workflow_dispatch`:

1. **Build** the boxes with Packer (one Packer builder per provider:
   `libvirt`, `virtualbox`, `vmware`, `hyperv`; x86_64, plus the
   `x86_64_v2` microarch for AL10 / Kitten).
2. **Test** each box with a live `vagrant up` smoke test on the build
   runner (via `shared-steps`, gated by `run_test`). Hyper-V is the
   exception - see below.
3. **Publish** each box to the HCP Vagrant Registry, **in-job on the same
   runner**, straight from the locally-built `.box` (no S3 round-trip),
   gated by `release_to_hcp`.

It reuses `shared-steps` for build+test (same as the standalone
[`vagrant-build.yml`](BUILD_VAGRANT.md) / [`hyperv-build.yml`](BUILD_VAGRANT.md))
and a new `vagrant-publish-steps` composite for the publish. The
standalone [`vagrant-publish.yml`](VAGRANT_CLOUD.md) remains for
publishing a box that already exists at a URL.

### Hyper-V is build-only (no live test)

A Hyper-V guest can't boot on the Linux runner, so there is no live
`vagrant up` test for it. Hyper-V builds as a `hyperv-x86_64` leg of the
`build-gh-hosted` job (not a separate job): that leg forces
`run_test=false`, so only `shared-steps`' offline validation (checksum +
installed-package list) runs, and the box is then published like the
others.

### When to use which

| Use | Workflow |
| :--- | :--- |
| Build + test + publish in one dispatch | this unified workflow |
| Just (re)build boxes (no publish) | `vagrant-build.yml` / `hyperv-build.yml` |
| Publish a box that already exists at a URL | `vagrant-publish.yml` |

## Workflow inputs

The input set is [`vagrant-build.yml`](BUILD_VAGRANT.md)'s plus
`release_to_hcp`; the publish workflow's `dry-run-mode` is omitted.

| Input | Default | Notes |
| :--- | :--- | :--- |
| `date_time_stamp` | auto (`date -u +%Y%m%d%H%M%S`) | Shared stamp for every matrix leg. |
| `version_major` | `10` | `10-kitten`, `10`, `9`, `8`. |
| `vagrant_type` | `ALL` | `ALL`, `vagrant_libvirt`, `vagrant_virtualbox`, `vagrant_vmware`, `vagrant_hyperv`. |
| `self-hosted` | `true` | Build the self-hosted providers on a self-hosted runner. |
| `self_hosted_runner` | `aws-ec2` | `self-hosted` (manual) or `aws-ec2`. Routes libvirt/virtualbox to the self-hosted leg when set to `self-hosted`. |
| `run_test` | `true` | Live `vagrant up` test (ignored for the hyperv leg, which is always build-only). |
| `store_as_artifact` | `false` | Upload boxes as workflow artifacts. |
| `upload_to_s3` | `true` | Upload to S3 in parallel; also used for the publish summary/notification link. |
| `release_to_hcp` | `true` | Publish boxes to the HCP Vagrant Registry. `false` = build+test only. |
| `notify_mattermost` | `true` | Post per-box build / publish notifications to Mattermost. |

## Job layout

```
init-data  (computes matrix_gh / matrix_sh from vagrant_type; adds
 |          hyperv-x86_64 to matrix_gh for ALL / vagrant_hyperv)
 |
 |- build-gh-hosted (matrix_gh x variant)   -. shared-steps build (+ vagrant up
 |     libvirt / virtualbox / hyperv          | test, except hyperv), then
 |                                            | vagrant-publish-steps in-job
 |- start-self-hosted-runner (fork EC2)       |
 '- build-self-hosted (matrix_sh x variant) -' (HCP publish, gated by release_to_hcp)
       vmware
```

There is no collect / aggregation stage: each box is published in-job,
right after it is built and tested. Provider routing (matching
`vagrant-build.yml`):

| Provider | Job (AlmaLinux org default) | Live test? |
| :--- | :--- | :--- |
| libvirt, virtualbox | `build-gh-hosted` (or `build-self-hosted` if `self_hosted_runner=self-hosted`) | yes |
| vmware | `build-self-hosted` (needs the AL9 AMI) | yes |
| hyperv | `build-gh-hosted` leg | no (build-only) |

### Publishing: parallel, with retry-on-collision

Publishes run **in parallel** across the provider/variant matrix. Sibling
providers of the same box publish to the **same** HCP box version (e.g.
`almalinux/10` gets libvirt + virtualbox + vmware + hyperv providers), so
they can race while that shared version is being created. There is no CLI
to detect an in-flight publish, so `vagrant-publish-steps` retries
`vagrant cloud publish` with backoff (up to 6 attempts); the only real
contention is the version-create race, which clears once a sibling
finishes (`vagrant cloud publish -f` is idempotent). Different boxes
(`10` vs `10-x86_64_v2`) are distinct HCP boxes and never contend.

An earlier design serialized publishes with a per-box `concurrency` group,
but GitHub Actions concurrency keeps at most one in-progress + one pending
job per group - a third same-group job cancels the pending one - so it
could not serialize 3+ providers. Retry-on-collision replaced it.

### Stage composite actions

| Stage | Composite action |
| :--- | :--- |
| Build + test | [`.github/actions/shared-steps`](.github/actions/shared-steps/action.yml) |
| Publish | [`.github/actions/vagrant-publish-steps`](.github/actions/vagrant-publish-steps/action.yml) |

`vagrant-publish-steps` is new - adapted from `vagrant-publish.yml` minus
dry-run: it sources the box from the local file, parses the filename for
the HCP box name / provider / version, installs the `hcp` CLI OS-aware
(apt on the Ubuntu libvirt/virtualbox/hyperv legs, dnf / HashiCorp RPM
repo on the EL9 vmware leg; `vagrant` is already present on every build
runner), and publishes with the retry loop above. It fails fast with a
clear message if the HCP credentials are empty (otherwise `hcp auth login`
falls back to an interactive browser login that hangs in CI).

## Runner sizing

| Job | Runner (AlmaLinux org) | Runner (forks) |
| :--- | :--- | :--- |
| `build-gh-hosted` | `r8i.2xlarge`, `image=ubuntu24-full-x64`, `volume=60g`, `nested-virt`, `spot=false` | `ubuntu-24.04` |
| `build-self-hosted` | `r8i.2xlarge`, `ami=<AL9 x86_64>`, `volume=60g`, `nested-virt`, `spot=false` | EC2 `c5n.metal` (`EC2_AMI_ID_AL9_X86_64`) or a manual self-hosted runner |

`nested-virt` provides KVM for the Packer build and the `vagrant up` test;
`vmware` needs the AlmaLinux 9 AMI (VMware Workstation), which is why it
lives on the self-hosted leg. **Hyper-V now builds on `build-gh-hosted`'s
`r8i.2xlarge`** rather than the metal family the standalone
`hyperv-build.yml` used - this matches the metal-to-`r8i.2xlarge`
migration the vagrant build already made; KVM is available either way.

`spot=false` pins the build runners on-demand to avoid spot-reclaim
cancellations mid-build (Vagrant builds are long); drop it or switch to a
spot allocation strategy if cost matters more than reclaim resilience.

## Required GitHub Configuration

### Secrets
| Secret | Description |
|--------|-------------|
| `HCP_CLIENT_ID` / `HCP_CLIENT_SECRET` | HCP service-principal credentials (publish). Without them the publish fails fast. |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | S3 upload (build stage) |
| `MATTERMOST_WEBHOOK_URL` | Mattermost incoming webhook URL |
| `GIT_HUB_TOKEN` | Packer plugin GitHub API token |
| `EC2_AMI_ID_AL9_X86_64`, `EC2_SUBNET_ID`, `EC2_SECURITY_GROUP_ID` | fork-only self-hosted EC2 runner |

### Variables (`vars.*`)
| Variable | Description |
|----------|-------------|
| `HCP_ORG` | HCP Vagrant Registry organization (e.g. `almalinux`) |
| `EC2_AMI_ID_AL9_X86_64` | AL9 x86_64 AMI for the org self-hosted (vmware) runner |
| `AWS_REGION`, `AWS_S3_BUCKET` | S3 upload target (also the publish summary link) |
| `MATTERMOST_CHANNEL` | Mattermost channel for notifications |

## Troubleshooting

1. **`unable to login to HCP: ... timed out waiting for response from
   provider`** (a browser-auth URL is printed) - `HCP_CLIENT_ID` /
   `HCP_CLIENT_SECRET` are empty, so `hcp auth login` fell back to
   interactive login. Set the secrets on the repo/org. The composite now
   guards this and fails fast with the `gh secret set` hint.
2. **Two build legs cancelled mid-build, ~simultaneously** - a run-level
   cancel (UI/API) or, on spot runners, a spot reclaim ("The runner has
   received a shutdown signal"). The build runners use `spot=false` to
   avoid the latter.
3. **`dnf -y remove --oldinstallonly` fails in the build** ("No old
   installonly packages found for removal") - a build-role issue in
   `shared-steps`' ansible, independent of this workflow.
4. **Publish hits a version-create conflict** - expected when sibling
   providers race on the same box version; the retry loop self-heals. A
   persistent failure exhausts the 6 attempts and fails the leg.

## See also

- [BUILD_VAGRANT.md](BUILD_VAGRANT.md) - the build stage (`shared-steps`), the per-provider Packer builders, and the `vagrant up` inline test.
- [VAGRANT_CLOUD.md](VAGRANT_CLOUD.md) - the standalone publish flow and the HCP box/version/provider model.
