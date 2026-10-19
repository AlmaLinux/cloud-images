#!/usr/bin/env python3
"""Add the boxes a "Vagrant: Build, Test and Publish" run built and tested to
the Vagrant box catalog.

The catalog is one metadata JSON per box (almalinux/9, almalinux/10,
almalinux/10-x86_64_v2, ...), served from S3; see tools/vagrant_catalog.py,
which built it from the HCP Vagrant registry snapshot.

Each --entry is a JSON file a build leg wrote for its box:
  {"file": "<box file name>", "s3_key": "<S3 key of the box>", "sha256": "<sha256>"}
The box file name gives the catalog box, version, provider and architecture,
as tools/vagrant_catalog.py names them (e.g.
AlmaLinux-10-Vagrant-vmware-10.2-20261012.0.aarch64.box ->
almalinux/10 10.2.20261012 vmware_desktop/arm64).

For each catalog box the entries touch, the script downloads its current
metadata (--catalog-url/<org>/<box>; it must exist), keeps a copy in
--previous, adds the version if needed and adds or replaces the entries'
providers in it (a re-run replaces, never duplicates), and writes the result
to --out as <org>/<box> and <org>/<box>.json. In the touched versions,
default_architecture is set on amd64, or on the only architecture of a
provider. It lists the changed boxes in --changed and writes a Markdown
summary to --report.
"""

import argparse
import collections
import importlib.util
import json
import os
import sys
import urllib.error
import urllib.request

TOOLS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tools")
spec = importlib.util.spec_from_file_location("vagrant_catalog", os.path.join(TOOLS, "vagrant_catalog.py"))
vagrant_catalog = importlib.util.module_from_spec(spec)
spec.loader.exec_module(vagrant_catalog)


def version_key(version):
    return [int(x) for x in version.split(".")]


def fetch(url):
    try:
        with urllib.request.urlopen(url, timeout=60) as resp:
            return json.load(resp)
    except urllib.error.HTTPError as err:
        sys.exit(f"[Error] {url}: HTTP {err.code} - the catalog file must exist "
                 f"(create a new box's catalog with tools/vagrant_catalog.py first)")


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n", 1)[0])
    parser.add_argument("--entry", nargs="+", required=True, help="the build legs' entry JSON files")
    parser.add_argument("--catalog-url", required=True, help="the catalog base URL, e.g. https://<bucket>.s3.us-east-1.amazonaws.com/vagrant")
    parser.add_argument("--box-url", required=True, help="the base URL of the box files, e.g. https://<bucket>.s3.amazonaws.com")
    parser.add_argument("--org", default="almalinux")
    parser.add_argument("--out", required=True, help="where to write the updated <org>/<box>[.json]")
    parser.add_argument("--previous", required=True, help="where to keep the downloaded <org>/<box>.json")
    parser.add_argument("--changed", required=True, help="file to write the changed box names to, one per line")
    parser.add_argument("--report", help="append a Markdown summary to this file")
    args = parser.parse_args()

    by_box = collections.defaultdict(list)
    for path in args.entry:
        with open(path) as f:
            entry = json.load(f)
        ident = vagrant_catalog.identify(entry["file"])
        if not ident:
            sys.exit(f"[Error] {path}: not a box file name: {entry['file']}")
        box, version, provider, arch = ident
        by_box[box].append({"version": version, "provider": {
            "name": provider,
            "url": f"{args.box_url.rstrip('/')}/{entry['s3_key']}",
            "checksum_type": "sha256",
            "checksum": entry["sha256"].lower(),
            "architecture": arch,
            "default_architecture": False,
        }})

    report, changed = [], []
    for box, entries in sorted(by_box.items()):
        url = f"{args.catalog_url.rstrip('/')}/{args.org}/{box}"
        catalog = fetch(url)
        if catalog.get("name") != f"{args.org}/{box}":
            sys.exit(f"[Error] {url}: unexpected catalog name {catalog.get('name')!r}")
        os.makedirs(os.path.join(args.previous, args.org), exist_ok=True)
        with open(os.path.join(args.previous, args.org, f"{box}.json"), "w") as f:
            json.dump(catalog, f, indent=2)
            f.write("\n")

        touched = collections.defaultdict(list)
        for entry in entries:
            version = next((v for v in catalog["versions"] if v["version"] == entry["version"]), None)
            if version is None:
                version = {"version": entry["version"], "status": "active", "providers": []}
                catalog["versions"].append(version)
            new = entry["provider"]
            replaced = any(p["name"] == new["name"] and p["architecture"] == new["architecture"]
                           for p in version["providers"])
            version["providers"] = [p for p in version["providers"]
                                    if not (p["name"] == new["name"] and p["architecture"] == new["architecture"])]
            version["providers"].append(new)
            touched[entry["version"]].append(f"{new['name']}/{new['architecture']}"
                                             + (" (replaced)" if replaced else ""))

        for version in catalog["versions"]:
            if version["version"] not in touched:
                continue
            by_name = collections.defaultdict(list)
            for p in version["providers"]:
                by_name[p["name"]].append(p)
            for providers in by_name.values():
                default = next((p for p in providers if p["architecture"] == "amd64"), providers[0])
                for p in providers:
                    p["default_architecture"] = p is default
        catalog["versions"].sort(key=lambda v: version_key(v["version"]))

        os.makedirs(os.path.join(args.out, args.org), exist_ok=True)
        text = json.dumps(catalog, indent=2) + "\n"
        for name in (box, f"{box}.json"):
            with open(os.path.join(args.out, args.org, name), "w") as f:
                f.write(text)
        changed.append(box)
        for version, providers in sorted(touched.items(), key=lambda kv: version_key(kv[0])):
            line = f"`{args.org}/{box}` **{version}**: {', '.join(sorted(providers))}"
            report.append(line)
            print(f"[Info] {args.org}/{box} {version}: {', '.join(sorted(providers))}", file=sys.stderr)

    with open(args.changed, "w") as f:
        f.write("".join(f"{box}\n" for box in changed))
    if args.report:
        with open(args.report, "a") as f:
            f.write("\n".join(f"- {line}" for line in report) + "\n")


if __name__ == "__main__":
    main()
