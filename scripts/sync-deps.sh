#!/usr/bin/env bash
# Sync lib/ JARs: move Maven Central ones to pom.xml, keep proprietary ones in lib/.
# Uses SHA1 fingerprint lookup for accurate matching.
# Usage: sync-deps.sh <extracted-jars-dir>
set -euo pipefail

JARS_DIR="${1:?Usage: $0 <extracted-jars-dir>}"
POM="pom.xml"

if ! command -v python3 &>/dev/null; then
  echo "ERROR: python3 is required" >&2
  exit 1
fi

python3 - "$JARS_DIR" "$POM" <<'PYEOF'
import sys
import json
import hashlib
import urllib.request
import urllib.parse
import xml.etree.ElementTree as ET
from pathlib import Path

jars_dir = Path(sys.argv[1])
pom_path = sys.argv[2]

NS = "http://maven.apache.org/POM/4.0.0"
ET.register_namespace("", NS)
ET.register_namespace("xsi", "http://www.w3.org/2001/XMLSchema-instance")

def sha1_of(path):
    h = hashlib.sha1()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()

def search_by_sha1(sha1):
    """Return (groupId, artifactId, version) if found on Maven Central, else None."""
    q = urllib.parse.quote(f'1:"{sha1}"')
    url = f'https://search.maven.org/solrsearch/select?q={q}&rows=1&wt=json'
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "sync-deps/1.0"})
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read())
        docs = data.get("response", {}).get("docs", [])
        if docs:
            d = docs[0]
            return d["g"], d["a"], d["v"]
    except Exception as e:
        print(f"  WARN: Maven Central query failed: {e}", file=sys.stderr)
    return None

def dep_exists(root, group_id, artifact_id):
    deps = root.find(f".//{{{NS}}}dependencies")
    if deps is None:
        return False
    for dep in deps.findall(f"{{{NS}}}dependency"):
        g = dep.findtext(f"{{{NS}}}groupId", "")
        a = dep.findtext(f"{{{NS}}}artifactId", "")
        if g == group_id and a == artifact_id:
            return True
    return False

def add_dependency(root, group_id, artifact_id, version):
    deps = root.find(f".//{{{NS}}}dependencies")
    dep = ET.SubElement(deps, f"{{{NS}}}dependency")
    ET.SubElement(dep, f"{{{NS}}}groupId").text = group_id
    ET.SubElement(dep, f"{{{NS}}}artifactId").text = artifact_id
    ET.SubElement(dep, f"{{{NS}}}version").text = version
    excls = ET.SubElement(dep, f"{{{NS}}}exclusions")
    excl = ET.SubElement(excls, f"{{{NS}}}exclusion")
    ET.SubElement(excl, f"{{{NS}}}groupId").text = "*"
    ET.SubElement(excl, f"{{{NS}}}artifactId").text = "*"
    print(f"  + Added to pom.xml: {group_id}:{artifact_id}:{version}")

tree = ET.parse(pom_path)
root = tree.getroot()

keep_in_lib = []
moved_to_pom = []

jars = sorted(jars_dir.glob("*.jar"))
print(f"Processing {len(jars)} JARs from {jars_dir}")

for jar in jars:
    print(f"  Checking {jar.name} ...", end=" ", flush=True)
    sha1 = sha1_of(jar)
    result = search_by_sha1(sha1)
    if result:
        group_id, artifact_id, version = result
        print(f"found ({group_id}:{artifact_id}:{version})")
        if not dep_exists(root, group_id, artifact_id):
            add_dependency(root, group_id, artifact_id, version)
        else:
            print(f"    already in pom.xml, skipping")
        moved_to_pom.append(jar.name)
    else:
        print("not on Maven Central, keeping in lib/")
        keep_in_lib.append(jar)

tree.write(pom_path, xml_declaration=True, encoding="UTF-8")

print(f"\nSummary:")
print(f"  Moved to pom.xml:  {len(moved_to_pom)}")
print(f"  Kept in lib/:      {len(keep_in_lib)}")

# Write list of JAR paths to keep in lib/
with open("lib-keep.txt", "w") as f:
    for jar in keep_in_lib:
        f.write(str(jar) + "\n")
PYEOF

echo "Done. JARs to keep in lib/ listed in lib-keep.txt"
