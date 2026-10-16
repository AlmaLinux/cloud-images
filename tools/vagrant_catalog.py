#!/usr/bin/env python3
"""Generate the Vagrant box catalog (one metadata JSON per box) for the
AlmaLinux boxes hosted on S3, to replace the HCP Vagrant Registry.

The released versions come from a snapshot of the HCP registry metadata
(one <box>.json per box, as `GET /api/v2/vagrant/almalinux/<box>` returns
it): the catalog lists exactly what was published there, never the test or
rebuild boxes that share the S3 prefixes. Each HCP provider entry is mapped
to the S3 box it was published from:

- by checksum, when HCP has a sha256 of the box: the S3 box whose
  .sha256sum matches (this picks the right build when a date has several)
- by name otherwise (sha512 or no checksum on HCP): the S3 box named as the
  build names it, for that version, provider and architecture

Entries with no S3 copy are left out and reported. Every provider gets the
sha256 from the box's .sha256sum, its S3 URL, and the architecture and
default_architecture HCP had, so `vagrant box add` resolves exactly as it
did on HCP. Boxes released after HCP closed can be added with --extra.

Vagrant reads the catalog through either:
  VAGRANT_SERVER_URL=<server>   then config.vm.box = "almalinux/9"
                                (Vagrant requests <server>/almalinux/9)
  config.vm.box_url = "<server>/almalinux/9"
The catalog must be served with Content-Type: application/json, or Vagrant
takes the URL for a box file. Both <box> and <box>.json are written.

Everything is read anonymously over HTTPS (the bucket allows public listing
of images/* and public reads of the objects tagged public=yes): no AWS
credentials are needed.

Usage:
  tools/vagrant_catalog.py --hcp-dir <DIR> --out <DIR> [--extra <TSV>]
                           [--base-url <URL>] [--verify]
"""

import argparse
import collections
import concurrent.futures
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET

S3_ENDPOINT = "https://almalinux-cloud.s3.amazonaws.com"
PREFIXES = ("images/8/", "images/9/", "images/10/", "images/kitten/")
ORG = "almalinux"
ARCH = {"x86_64": "amd64", "x86_64_v2": "amd64", "aarch64": "arm64"}
PROVIDER = {"vmware": "vmware_desktop"}

MODERN = re.compile(
    r"^AlmaLinux-(Kitten|\d+)-Vagrant-([a-z]+)-([0-9.]+)-([0-9.]+)"
    r"\.(aarch64|x86_64)(_v2)?\.box$")
LEGACY = re.compile(
    r"^AlmaLinux-(\d+)-Vagrant-([0-9.]+)-(\d+)"
    r"\.(aarch64|x86_64)(_v2)?\.([a-z]+)\.box$")


def log(msg):
    print(msg, file=sys.stderr)


def http(url, method="GET"):
    req = urllib.request.Request(url, method=method)
    with urllib.request.urlopen(req, timeout=60) as resp:
        return resp.status, resp.headers, resp.read() if method == "GET" else b""


def s3_list(endpoint, prefix):
    """Yield (key, size) of the objects under prefix (anonymous ListObjectsV2)."""
    token = None
    while True:
        query = {"list-type": "2", "prefix": prefix}
        if token:
            query["continuation-token"] = token
        _, _, body = http(f"{endpoint}/?{urllib.parse.urlencode(query)}")
        root = ET.fromstring(body)
        ns = root.tag[: root.tag.index("}") + 1] if root.tag.startswith("{") else ""
        for item in root.iter(f"{ns}Contents"):
            yield item.find(f"{ns}Key").text, int(item.find(f"{ns}Size").text)
        if root.findtext(f"{ns}IsTruncated") != "true":
            return
        token = root.findtext(f"{ns}NextContinuationToken")


def identify(file_name):
    """(box, version, provider, architecture) of a box file, as on HCP."""
    m = MODERN.match(file_name)
    if m:
        major, prov, release, date, arch, v2 = m.groups()
        box = ("10-kitten" if major == "Kitten" else major) + ("-x86_64_v2" if v2 else "")
        if major != "Kitten":
            date = re.sub(r"\.\d+$", "", date)  # the build index is not in the version
        return box, f"{release}.{date}", PROVIDER.get(prov, prov), ARCH[arch]
    m = LEGACY.match(file_name)
    if m:
        major, release, date, arch, v2, prov = m.groups()
        box = major + ("-x86_64_v2" if v2 else "")
        return box, f"{release}.{date}", PROVIDER.get(prov, prov), ARCH[arch]
    return None


def version_key(version):
    return [int(x) for x in version.split(".")]


def load_s3(endpoint):
    """The boxes on S3: {key: size}, {key: sha256}."""
    sizes, sums = {}, {}
    for prefix in PREFIXES:
        for key, size in s3_list(endpoint, prefix):
            if "/vagrant/" in key:
                sizes[key] = size
    boxes = [k for k in sizes if k.endswith(".box")]
    with_sum = [k for k in boxes if f"{k}.sha256sum" in sizes]

    def fetch(key):
        try:
            _, _, body = http(f"{endpoint}/{urllib.parse.quote(key)}.sha256sum")
            return key, body.decode().split()[0].lower()
        except (urllib.error.URLError, IndexError) as err:
            log(f"[Warning] Cannot read {key}.sha256sum: {err}")
            return key, None

    with concurrent.futures.ThreadPoolExecutor(16) as pool:
        for key, digest in pool.map(fetch, with_sum):
            if digest:
                sums[key] = digest
    log(f"[Info] S3: {len(boxes)} boxes, {len(sums)} with a readable .sha256sum")
    return {k: sizes[k] for k in boxes}, sums


def build(hcp_dir, extra, base_url, endpoint):
    sizes, sums = load_s3(endpoint)
    by_sum = collections.defaultdict(list)
    by_ident = collections.defaultdict(list)
    for key in sizes:
        ident = identify(key.rsplit("/", 1)[1])
        if not ident:
            log(f"[Warning] Unknown box file name: {key}")
            continue
        by_ident[ident].append(key)
        if key in sums:
            by_sum[sums[key]].append(key)

    def provider_entry(key, name, arch, default):
        return {
            "name": name,
            "url": f"{base_url}/{urllib.parse.quote(key)}",
            "checksum_type": "sha256",
            "checksum": sums[key],
            "architecture": arch,
            "default_architecture": default,
        }

    catalogs, report, used = {}, collections.Counter(), {}
    omitted = []
    for file_name in sorted(os.listdir(hcp_dir)):
        if not file_name.endswith(".json"):
            continue
        with open(os.path.join(hcp_dir, file_name)) as f:
            hcp = json.load(f)
        box = hcp["name"].split("/", 1)[1]
        versions = []
        for hv in sorted(hcp["versions"], key=lambda v: version_key(v["version"])):
            providers = []
            for hp in hv["providers"]:
                arch = hp["architecture"]
                archs = ["amd64", "arm64"] if arch == "unknown" else [arch]
                named = [k for a in archs for k in by_ident[(box, hv["version"], hp["name"], a)]]
                what = f"{ORG}/{box} {hv['version']} {hp['name']}/{arch}"
                sum_type = (hp.get("checksum_type") or "none").lower()
                hcp_sum = (hp.get("checksum") or "").lower()
                if sum_type == "sha256":
                    keys = by_sum.get(hcp_sum, [])
                    # Prefer the copy named for this version, if the same file
                    # was uploaded under several names
                    keys = sorted([k for k in keys if k in named] or keys)
                    if not keys:
                        omitted.append(f"{what}: no S3 box has the HCP sha256 {hcp_sum}")
                        continue
                    key, how = keys[0], "checksum"
                else:
                    keys = sorted(k for k in named if k in sums)
                    if not keys:
                        omitted.append(f"{what}: no S3 box named for it (HCP checksum: {sum_type})")
                        continue
                    if len(keys) > 1:
                        log(f"[Warning] {what}: {len(keys)} S3 boxes, taking the oldest {keys[0]}")
                    key, how = keys[0], "name"
                report[how] += 1
                used[key] = what
                providers.append(provider_entry(key, hp["name"], arch, hp["default_architecture"]))
            if providers:
                versions.append({"version": hv["version"], "status": "active", "providers": providers})
        catalogs[box] = {
            "name": f"{ORG}/{box}",
            "description": hcp.get("description") or hcp.get("short_description") or "",
            "versions": versions,
        }

    # Boxes released after HCP closed: one S3 key per line
    if extra:
        added = collections.defaultdict(list)
        with open(extra) as f:
            for line in f:
                key = line.split("#", 1)[0].strip()
                if not key:
                    continue
                ident = identify(key.rsplit("/", 1)[1])
                if not ident or key not in sizes or key not in sums:
                    sys.exit(f"[Error] --extra: {key} is not a box with a .sha256sum on S3")
                added[ident[:2]].append((key, ident))
        for (box, version), entries in added.items():
            catalog = catalogs.setdefault(box, {"name": f"{ORG}/{box}", "description": "", "versions": []})
            target = next((v for v in catalog["versions"] if v["version"] == version), None)
            if target is None:
                target = {"version": version, "status": "active", "providers": []}
                catalog["versions"].append(target)
            names = collections.defaultdict(list)
            for key, (_, _, name, arch) in entries:
                if any(p["name"] == name and p["architecture"] == arch for p in target["providers"]):
                    sys.exit(f"[Error] --extra: {ORG}/{box} {version} already has {name}/{arch}")
                names[name].append((arch, key))
            for name, items in names.items():
                # As HCP marked it: amd64 is the default when there is one
                existing = any(p["name"] == name and p["default_architecture"] for p in target["providers"])
                items.sort(key=lambda i: i[0] != "amd64")
                for n, (arch, key) in enumerate(items):
                    target["providers"].append(provider_entry(key, name, arch, n == 0 and not existing))
                    used[key] = f"{ORG}/{box} {version} {name}/{arch}"
                    report["extra"] += 1
            catalog["versions"].sort(key=lambda v: version_key(v["version"]))

    return catalogs, report, omitted, used, sizes


def verify(catalogs, sizes, base_url):
    """HEAD every box URL anonymously: 200 and the S3 size."""
    urls = [(p["url"], v["version"], c["name"], p)
            for c in catalogs.values() for v in c["versions"] for p in v["providers"]]
    prefix = f"{base_url}/"

    def head(item):
        url = item[0]
        key = urllib.parse.unquote(url[len(prefix):])
        try:
            status, headers, _ = http(url, "HEAD")
            size = int(headers.get("Content-Length", -1))
        except urllib.error.HTTPError as err:
            status, size = err.code, -1
        except urllib.error.URLError as err:
            status, size = str(err.reason), -1
        return item, status, size, sizes.get(key)

    bad = 0
    with concurrent.futures.ThreadPoolExecutor(16) as pool:
        for (url, version, name, _), status, size, expected in pool.map(head, urls):
            if status != 200 or size != expected:
                bad += 1
                log(f"[Error] {name} {version}: {url}: HTTP {status}, {size} of {expected} bytes")
    log(f"[Info] Verified {len(urls)} box URLs: {len(urls) - bad} OK, {bad} failed")
    return bad == 0


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n", 1)[0])
    parser.add_argument("--hcp-dir", required=True, help="the HCP registry metadata snapshot, <box>.json per box")
    parser.add_argument("--out", required=True, help="where to write <org>/<box> and <org>/<box>.json")
    parser.add_argument("--extra", help="S3 keys of boxes released after HCP closed, one per line")
    parser.add_argument("--base-url", default=S3_ENDPOINT, help=f"the box URL base in the catalog (default {S3_ENDPOINT})")
    parser.add_argument("--s3-endpoint", default=S3_ENDPOINT, help="where to list and read the bucket anonymously")
    parser.add_argument("--verify", action="store_true", help="HEAD every box URL (anonymous) and check its size")
    args = parser.parse_args()
    base_url = args.base_url.rstrip("/")

    catalogs, report, omitted, used, sizes = build(args.hcp_dir, args.extra, base_url, args.s3_endpoint.rstrip("/"))

    os.makedirs(os.path.join(args.out, ORG), exist_ok=True)
    for box, catalog in sorted(catalogs.items()):
        text = json.dumps(catalog, indent=2) + "\n"
        for name in (box, f"{box}.json"):
            with open(os.path.join(args.out, ORG, name), "w") as f:
                f.write(text)
        providers = sum(len(v["providers"]) for v in catalog["versions"])
        log(f"[Info] {catalog['name']}: {len(catalog['versions'])} versions, {providers} providers")

    log(f"[Info] Mapped to S3 by checksum: {report['checksum']}, by name: {report['name']}, extra: {report['extra']}")
    for line in omitted:
        log(f"[Warning] Left out: {line}")
    if len(used) != sum(report.values()):
        log("[Warning] Some S3 boxes are used by more than one catalog entry")

    ok = verify(catalogs, sizes, base_url) if args.verify else True
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
