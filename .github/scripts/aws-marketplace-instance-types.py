#!/usr/bin/env python3
"""Sync the instance types of the AlmaLinux AWS Marketplace AMI products
with the instance types EC2 offers.

An AWS Marketplace AMI product carries an explicit list of the instance
types it can be launched on, and AWS does not add new instance families to
existing products: until the seller adds them, customers get "The instance
configuration for this AWS Marketplace product is not supported".

For each AMI product whose name matches --product-pattern, the script lists
the instance types that are
- offered by EC2 in any enabled region, for the product's architecture
  (taken from its name: "(x86_64)" or "(arm64)"; for a product without one
  in the name, such as almalinux-dev, from the types it already allows),
- current generation, with ENA support,
- not yet among the product's available instance types,
- not among its restricted instance types (deliberately restricted by the
  seller), and
- not matched by an --exclude pattern (fnmatch, e.g. "*.nano").

It writes a Markdown report and a short Mattermost message. With --sync it
submits one change set per product, with the three changes an AMI product
with per-instance-type ("internally metered") pricing needs - even a free
one:
- AddDimensions: an hourly Metered pricing dimension per new type, like the
  product's existing ones;
- AddInstanceTypes: the new types;
- UpdatePricingTerms on the product's offer: its usage rate card with a
  "0.00" rate added for each new type.
It submits the change sets of all products first, then waits for all of
their verdicts together, each up to --wait minutes from its submission. If
AWS rejects a product's change set only for types it does not know yet
(INVALID_INSTANCE_TYPES on AddInstanceTypes, or INVALID_INPUT "invalid
dimension key" on AddDimensions - types EC2 already offers), the script drops
exactly those and resubmits that product's change set right away, up to
MAX_RETRIES times. A change set still in
progress when its wait ends is reported as submitted.

Everything goes through the AWS CLI (v2), with the caller's credentials; the
Marketplace Catalog API is in us-east-1.

Usage:
  aws-marketplace-instance-types.py [--sync] [--exclude PATTERN ...]
      [--product-pattern PATTERN] [--report FILE] [--message FILE]
      [--github-output FILE] [--run-url URL] [--wait MINUTES]
"""

import argparse
import collections
import concurrent.futures
import datetime
import fnmatch
import json
import re
import subprocess
import sys
import time

CATALOG = "AWSMarketplace"
CATALOG_REGION = "us-east-1"
MANAGEMENT_URL = "https://aws.amazon.com/marketplace/management/requests"
# Resubmissions of a change set AWS rejected only for types it does not know
# yet (the checks run change by change, so a resubmission can reveal more)
MAX_RETRIES = 2


def aws(*args, region=CATALOG_REGION):
    """Run an AWS CLI command and return its JSON output."""
    cmd = ["aws", *args, "--region", region, "--output", "json"]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"{' '.join(args[:2])}: {result.stderr.strip()}")
    return json.loads(result.stdout) if result.stdout.strip() else {}


def log(msg):
    print(msg, file=sys.stderr, flush=True)


def region_instance_types(region):
    try:
        return region, aws("ec2", "describe-instance-types", "--cli-connect-timeout", "15", "--query",
                           "InstanceTypes[].{t:InstanceType,a:ProcessorInfo.SupportedArchitectures,"
                           "c:CurrentGeneration,e:NetworkInfo.EnaSupport}", region=region)
    except RuntimeError as err:
        log(f"[Warning] {region}: {err}")
        return region, []


def ec2_instance_types():
    """{type: {architectures, current generation, ENA}} across all enabled regions."""
    regions = [r["RegionName"] for r in aws("ec2", "describe-regions")["Regions"]]
    types = {}
    with concurrent.futures.ThreadPoolExecutor(8) as pool:
        for region, found in pool.map(region_instance_types, sorted(regions)):
            for it in found:
                types[it["t"]] = {"arch": set(it["a"] or []), "current": bool(it["c"]),
                                  "ena": it["e"] != "unsupported"}
    log(f"[Info] EC2: {len(types)} instance types in {len(regions)} regions")
    # Every region failing (e.g. no ec2:DescribeInstanceTypes) would make
    # every product look up to date
    if not types:
        raise RuntimeError("EC2: no instance types in any region, see the warnings above")
    return types


def allowed_arch(allowed, ec2):
    """The architecture (x86_64 or arm64) of most of the allowed instance types."""
    count = collections.Counter(a for t in allowed for a in ec2.get(t, {}).get("arch", ())
                                if a in ("x86_64", "arm64"))
    return count.most_common(1)[0][0] if count else None


def products(pattern, ec2):
    entities = aws("marketplace-catalog", "list-entities", "--catalog", CATALOG,
                   "--entity-type", "AmiProduct")["EntitySummaryList"]
    for entity in sorted(entities, key=lambda e: e["Name"]):
        if not fnmatch.fnmatchcase(entity["Name"], pattern):
            continue
        name = entity["Name"]
        details = aws("marketplace-catalog", "describe-entity", "--catalog", CATALOG,
                      "--entity-id", entity["EntityId"])["DetailsDocument"]
        if isinstance(details, str):
            details = json.loads(details)
        compat = details.get("Compatibility", {})
        arch = "arm64" if "(arm64)" in name else "x86_64" if "(x86_64)" in name else None
        if arch is None:
            arch = allowed_arch(compat.get("AvailableInstanceTypes", []), ec2)
            if arch is None:
                log(f"[Warning] {name}: no architecture in the name or the allowed types, skipped")
                continue
            log(f"[Info] {name}: architecture {arch}, from the instance types it allows")
        yield {"id": entity["EntityId"], "name": name, "arch": arch,
               "available": set(compat.get("AvailableInstanceTypes", [])),
               "restricted": set(compat.get("RestrictedInstanceTypes", [])),
               "dimensions": {d["Key"] for d in details.get("Dimensions", [])}}


def offers():
    """{product entity ID: (offer entity ID, offer details)} of all offers."""
    result = {}
    for entity in aws("marketplace-catalog", "list-entities", "--catalog", CATALOG,
                      "--entity-type", "Offer")["EntitySummaryList"]:
        details = aws("marketplace-catalog", "describe-entity", "--catalog", CATALOG,
                      "--entity-id", entity["EntityId"])["DetailsDocument"]
        if isinstance(details, str):
            details = json.loads(details)
        if details.get("ProductId"):
            result[details["ProductId"]] = (entity["EntityId"], details)
    return result


def families(types):
    count = collections.Counter(t.split(".")[0] for t in types)
    return ", ".join(f"{f} ({n})" for f, n in sorted(count.items()))


def change_set_name(text):
    """A change set name AWS accepts: ^[\\w\\s+=.:@-]{1,100}$ (no parentheses)."""
    return re.sub(r"\s+", " ", re.sub(r"[^\w\s+=.:@-]", "", text)).strip()[:100]


def add_instance_types(product, offer, types, name):
    """Submit the AddDimensions + AddInstanceTypes + UpdatePricingTerms change set."""
    offer_id, offer_details = offer
    usage = [t for t in offer_details.get("Terms", []) if t["Type"] == "UsageBasedPricingTerm"]
    if len(usage) != 1 or len(usage[0].get("RateCards", [])) != 1:
        raise RuntimeError(f"offer {offer_id}: expected one usage rate card, cannot add the $0 rates")
    rate_card = list(usage[0]["RateCards"][0]["RateCard"])
    priced = {r["DimensionKey"] for r in rate_card}
    rate_card += [{"DimensionKey": t, "Price": "0.00"} for t in types if t not in priced]
    dimensions = [{"Key": t, "Name": t, "Description": t, "Unit": "Hrs", "Types": ["Metered"]}
                  for t in types if t not in product["dimensions"]]
    product_entity = {"Type": "AmiProduct@1.0", "Identifier": product["id"]}
    change_set = []
    if dimensions:
        change_set.append({"ChangeType": "AddDimensions", "Entity": product_entity,
                           "Details": json.dumps(dimensions)})
    change_set.append({"ChangeType": "AddInstanceTypes", "Entity": product_entity,
                       "Details": json.dumps({"InstanceTypes": types})})
    change_set.append({"ChangeType": "UpdatePricingTerms",
                       "Entity": {"Type": "Offer@1.0", "Identifier": offer_id},
                       "Details": json.dumps({"PricingModel": "Usage", "Terms": [{
                           "Type": "UsageBasedPricingTerm",
                           "CurrencyCode": usage[0].get("CurrencyCode", "USD"),
                           "RateCards": [{"RateCard": rate_card}]}]})})
    result = aws("marketplace-catalog", "start-change-set", "--catalog", CATALOG,
                 "--change-set-name", name, "--change-set", json.dumps(change_set))
    return result["ChangeSetId"]


def change_set_result(change_set_id):
    """(status, [(error code, message)]) once the change set is done, else None."""
    result = aws("marketplace-catalog", "describe-change-set", "--catalog", CATALOG,
                 "--change-set-id", change_set_id)
    status = result["Status"]
    if status not in ("SUCCEEDED", "FAILED", "CANCELLED"):
        return None
    errors = [(e.get("ErrorCode", ""), e.get("ErrorMessage", ""))
              for c in result.get("ChangeSet", []) for e in c.get("ErrorDetailList", [])]
    if status != "SUCCEEDED" and not errors:
        errors = [(result.get("FailureCode", ""), result.get("FailureDescription", ""))]
    return status, errors


def invalid_types(errors):
    """The instance types AWS does not know yet, from a failed change set's errors:
    - INVALID_INSTANCE_TYPES: "Following instance types '[a, b]' are not valid"
      (AddInstanceTypes)
    - INVALID_INPUT: "Remove invalid dimension key 'a' for Metered dimension."
      (AddDimensions)"""
    found = set()
    for code, message in errors:
        if code == "INVALID_INSTANCE_TYPES":
            for group in re.findall(r"\[([^\]]*)\]", message):
                found.update(t.strip(" '\"") for t in group.split(",") if t.strip(" '\""))
        elif code == "INVALID_INPUT":
            found.update(re.findall(r"invalid dimension key '([^']+)'", message))
    return found


def only_unknown_types(errors, types):
    """True if every error of a failed change set is about types AWS does not know."""
    return bool(errors) and all(
        code == "INVALID_INSTANCE_TYPES"
        or (code == "INVALID_INPUT" and re.search(r"invalid dimension key '[^']+'", message))
        for code, message in errors) and bool(invalid_types(errors) & set(types))


def submit(job, minutes):
    """Submit a job's change set and set its wait deadline; on failure, record it in the job."""
    try:
        job["change_set_id"] = add_instance_types(job["product"], job["offer"], job["types"], job["name"])
        job["deadline"] = time.time() + minutes * 60
        log(f"[Info] {job['product']['name']}: change set {job['change_set_id']} submitted "
            f"({len(job['types'])} types)")
        return True
    except RuntimeError as err:
        job.update(status=f"change set failed: {err}", failed=True)
        log(f"[Error] {job['product']['name']}: {err}")
        return False


def sync_products(jobs, minutes):
    """Submit every product's change set, then wait for all of them together,
    each up to `minutes` from its submission. A change set AWS rejects only
    for instance types it does not know yet is resubmitted right away, once,
    without them. Sets each job's "status" (and "failed")."""
    pending = [job for job in jobs if submit(job, minutes)]
    while pending:
        for job in list(pending):
            name = job["product"]["name"]
            link = f"[{job['change_set_id']}]({MANAGEMENT_URL}/{job['change_set_id']})"
            result = change_set_result(job["change_set_id"])
            if result is None:
                if time.time() >= job["deadline"]:
                    pending.remove(job)
                    job["status"] = f"change set {link} submitted, still in progress"
                    log(f"[Info] {name}: change set {job['change_set_id']} still in progress")
                continue
            pending.remove(job)
            status, errors = result
            log(f"[Info] {name}: change set {job['change_set_id']}: {status}")
            if status == "SUCCEEDED":
                job["status"] = f"{len(job['types'])} added, change set {link} succeeded"
                continue
            unknown = invalid_types(errors) & set(job["types"])
            if (job.setdefault("retries", 0) < MAX_RETRIES and only_unknown_types(errors, job["types"])
                    and len(unknown) < len(job["types"])):
                log(f"[Warning] {name}: AWS does not know {sorted(unknown)} yet, resubmitting without them")
                job["retries"] += 1
                job["types"] = [t for t in job["types"] if t not in unknown]
                job["skipped"] = sorted(set(job.get("skipped", [])) | unknown)
                if submit(job, minutes):
                    pending.append(job)
                continue
            summary = "; ".join(f"{code}: {message[:300]}" for code, message in errors)
            log(f"[Error] {name}: change set {job['change_set_id']} {status}: {summary}")
            job.update(status=f"change set {link} {status.lower()}: {summary}", failed=True)
        if pending:
            time.sleep(30)
    for job in jobs:
        if job.get("skipped") and not job.get("failed"):
            job["status"] += " (not accepted by AWS yet: " + ", ".join(job["skipped"]) + ")"


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n", 1)[0])
    parser.add_argument("--sync", action="store_true", help="add the new instance types to the products")
    parser.add_argument("--exclude", nargs="*", default=[], help="fnmatch patterns of instance types never to add")
    parser.add_argument("--product-pattern", default="AlmaLinux OS *", help="fnmatch pattern of the product names")
    parser.add_argument("--report", help="append the Markdown report to this file ($GITHUB_STEP_SUMMARY)")
    parser.add_argument("--message", help="write the Mattermost message to this file")
    parser.add_argument("--github-output", help="append the step outputs to this file ($GITHUB_OUTPUT)")
    parser.add_argument("--run-url", default="", help="link to the workflow run, for the message")
    parser.add_argument("--wait", type=float, default=20, help="minutes to wait for each change set's result")
    args = parser.parse_args()

    ec2 = ec2_instance_types()
    product_offers = offers() if args.sync else {}
    excluded = lambda t: any(fnmatch.fnmatchcase(t, p) for p in args.exclude)
    today = datetime.date.today().isoformat()
    mode = "sync" if args.sync else "report only"

    results = []
    for product in products(args.product_pattern, ec2):
        new = sorted(t for t, v in ec2.items()
                     if product["arch"] in v["arch"] and v["current"] and v["ena"]
                     and t not in product["available"] and t not in product["restricted"]
                     and not excluded(t))
        log(f"[Info] {product['name']} ({product['id']}): {len(product['available'])} available, "
            f"{len(new)} new: {families(new) or '-'}")
        results.append({"product": product, "new": new, "types": list(new),
                        "status": "new types available" if new else "up to date", "failed": False,
                        "offer": product_offers.get(product["id"]),
                        "name": change_set_name(f"Add new EC2 instance types {today} to {product['name']}")})
    found = len(results)

    if args.sync:
        jobs = []
        for job in results:
            if not job["new"]:
                continue
            if job["offer"] is None:
                job.update(status="change set failed: no offer found for the product", failed=True)
                log(f"[Error] {job['product']['name']}: no offer found for the product")
                continue
            jobs.append(job)
        sync_products(jobs, args.wait)

    rows, details, message_lines = [], [], []
    total_new = products_new = failed = 0
    for job in results:
        product, new, status = job["product"], job["new"], job["status"]
        failed += job["failed"]
        if new:
            total_new += len(new)
            products_new += 1
            details.append(f"<details><summary>{product['name']}: {len(new)}</summary>\n\n"
                           + " ".join(f"`{t}`" for t in new) + "\n\n</details>\n")
            message_lines.append(f"- **{product['name']}**: {len(new)} - {families(new)}"
                                 + (f" - {status}" if args.sync else ""))
        rows.append(f"| {product['name']} | `{product['id']}` | {len(product['available'])} "
                    f"| {len(new)} | {families(new) or '-'} | {status} |")

    if not found:
        log(f"[Error] No AMI product matches '{args.product_pattern}'")
        return 1

    report = [f"## AWS Marketplace instance types ({mode})", "",
              f"EC2 instance types (current generation, ENA, all enabled regions) not yet "
              f"available on the AlmaLinux AMI products. Excluded patterns: "
              + (" ".join(f"`{p}`" for p in args.exclude) or "none") + ".", "",
              "| Product | Entity | Available | New | Families | Status |",
              "| :--- | :--- | ---: | ---: | :--- | :--- |", *rows, ""]
    if details:
        report += ["### New instance types by product", "", *details]
    if args.report:
        with open(args.report, "a") as f:
            f.write("\n".join(report) + "\n")
    else:
        print("\n".join(report))

    if args.message:
        if total_new:
            verb = "submitted for addition" if args.sync else "available for addition"
            text = [f":almalinux: **AWS Marketplace**: {total_new} new EC2 instance type(s) {verb} "
                    f"to {products_new} AlmaLinux product(s), by the GitHub [Action]({args.run_url})", "",
                    *message_lines]
            if not args.sync:
                text += ["", "Run the workflow with `sync` to add them."]
        else:
            text = [f":almalinux: **AWS Marketplace**: the AlmaLinux products are up to date with "
                    f"the EC2 instance types, by the GitHub [Action]({args.run_url})"]
        with open(args.message, "w") as f:
            f.write("\n".join(text) + "\n")

    if args.github_output:
        with open(args.github_output, "a") as f:
            f.write(f"total_new={total_new}\nproducts_new={products_new}\nfailed={failed}\n")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
