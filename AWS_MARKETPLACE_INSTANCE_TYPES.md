# AWS: Sync Marketplace instance types

## Why

An AWS Marketplace AMI product carries an explicit list of the instance
types it can be launched on, and AWS does not add new instance families to
existing products. Until the seller adds a new family, customers who launch
an AlmaLinux product on it get:

```
The instance configuration for this AWS Marketplace product is not supported
```

The release workflow ([AWS_BUILD_TEST_COPY_RELEASE.md](AWS_BUILD_TEST_COPY_RELEASE.md))
only adds new versions (AMIs) to the products; it does not touch their
instance types.

## What it does

`.github/workflows/aws-marketplace-instance-types.yml` runs
`.github/scripts/aws-marketplace-instance-types.py` weekly (Wednesdays,
06:43 UTC) and on demand. For every AMI product named `AlmaLinux OS *`
(`PRODUCT_PATTERN`; or one product, chosen with the `product` input), it lists the EC2 instance types that are:

- offered by EC2 in any enabled region, for the product's architecture
  (taken from the product name: `(x86_64)` or `(arm64)`);
- current generation, with ENA support;
- not yet among the product's available instance types
  (`Compatibility.AvailableInstanceTypes`);
- not among the product's restricted instance types
  (`Compatibility.RestrictedInstanceTypes`, restricted on purpose by the
  seller);
- not matched by `EXCLUDE_INSTANCE_TYPES`.

The result goes to the job summary (a table per product, and the full lists)
and to Mattermost.

With `sync=true` it then adds them: one change set per product (Marketplace
Catalog API, `us-east-1`), named `Add new EC2 instance types <date> to
<product>` (without the parentheses of the product name, which change set
names do not allow). Our products price every instance type (an hourly,
`Metered` dimension at $0), so - free as they are - adding a type takes three
changes in that change set, or AWS rejects it (`INVALID_DIMENSIONS`,
`UPDATE_PRICING_REQUIRED`):

1. `AddDimensions` on the product: an hourly `Metered` dimension per new type,
   like the existing ones;
2. `AddInstanceTypes` on the product: the new types;
3. `UpdatePricingTerms` on the product's offer: its usage rate card, with a
   `0.00` rate added for each new type.

AWS validates a change set asynchronously - including whether the product's
AMI is compatible with each type. The script submits the change sets of all
products first, then waits for all of their verdicts together, each up to 20
minutes from its submission (`--wait`), so a sync of `ALL` takes about as
long as one product (a change set typically succeeds within minutes - about
6 on `almalinux-dev`). If AWS rejects a product's change set only for types the Marketplace does
not know yet, although EC2 already offers them - `INVALID_INSTANCE_TYPES` on
`AddInstanceTypes` (e.g. `trn2u.48xlarge`), or `INVALID_INPUT` "Remove
invalid dimension key '…' for Metered dimension" on `AddDimensions` (e.g.
`c7gn.metal`, `i8g.48xlarge`, `r9g.medium` in October 2026) - the script
drops exactly those types and resubmits that product's change set right
away, up to twice (AWS checks the changes one by one, so a resubmission can
reveal more). The summary names the skipped types, and they come back in a
later week's report. Any other failure fails the run, with AWS's error
codes in the summary; it does not stop the other products. A change set still
in progress when its wait ends is reported as submitted. The summary and the message link each change set in the AWS
Marketplace Management Portal; follow it there or with
`aws marketplace-catalog describe-change-set --region us-east-1 --catalog AWSMarketplace --change-set-id <id>`.
A product with a change set already in progress (for example a release being
published) fails with `ResourceInUseException`; the run reports it and fails,
and the next run retries.

## Inputs

| Input | Default | Notes |
| :--- | :--- | :--- |
| `product` | `ALL` | One of the eight AlmaLinux products (`AlmaLinux OS 8 (x86_64)` … `AlmaLinux OS Kitten 10 (arm64)`), `almalinux-dev`, or `ALL`: every product matching `PRODUCT_PATTERN` (not `almalinux-dev`). |
| `sync` | `false` | Add the new instance types to the products. `false` = report only. |
| `notify_mattermost` | `true` | Post the result to Mattermost. |

Scheduled runs use the defaults: they check **all** products and **report only**.

`almalinux-dev` is the limited-visibility development product (x86_64 - its
architecture is taken from the types it allows, as its name has none). It is
priced like the public products, so a sync on it exercises the same change
set without touching anything customers can launch: use it to try changes to
the sync first. To add the reported
types, run the workflow manually with `sync`.

Mattermost gets a message when there is something to act on: new instance
types (report only), a sync, or a failed run. Weeks with the products up to
date only produce the job summary.

## Excluded instance types

`EXCLUDE_INSTANCE_TYPES` in the workflow holds `fnmatch` patterns of types
never to add:

| Pattern | Why |
| :--- | :--- |
| `*.nano` | No product allows a `.nano` size (512 MB of memory) |
| `trn2u.*` | Trn2 UltraServer type, offered only in ap-south-2: the Marketplace rejects it as not valid (`INVALID_INSTANCE_TYPES`, 2026-10-15). Drop the pattern once the Marketplace accepts it. |

GPU and accelerator types are not excluded: the products already allow
older ones (`g4dn` to `g6e`, `p4d` to `p5en`, `trn1`, `inf1`/`inf2`, `dl1`,
`g5g` on arm64), so their new families are added the same way. Types a
product restricts on purpose (its `RestrictedInstanceTypes`, such as `d2`,
`i2`, `i3`, `g2`, `g3`) are never added either.

Edit the list in the workflow to add or remove patterns.

## Requirements

- Secrets `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` of the AlmaLinux
  seller account (the ones the release workflow uses), with
  `aws-marketplace:ListEntities`, `DescribeEntity`, `StartChangeSet` and
  `DescribeChangeSet` (on the products and their offers), and
  `ec2:DescribeRegions` / `ec2:DescribeInstanceTypes`. In the AlmaLinux
  account these are the CI bot's (`bots/almalinux-cloud-bot`), granted by
  the `almalinux_cloud_ec2` policy. If no region returns any instance type
  (for example without `ec2:DescribeInstanceTypes`), the run fails rather
  than report every product as up to date.
- Secret `MATTERMOST_WEBHOOK_URL` and variable `MATTERMOST_CHANNEL`.

Scheduled runs happen only in the `AlmaLinux/cloud-images` repository; forks
can run the workflow manually.

## Running the script locally

```bash
.github/scripts/aws-marketplace-instance-types.py \
  --exclude '*.nano' 'trn2u.*'
```

prints the report with your AWS CLI credentials and changes nothing; add
`--sync` to submit the change sets.
