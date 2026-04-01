#!/usr/bin/env bash
# Sync lib/ JARs: move Maven Central ones to pom.xml, keep proprietary ones in lib/.
#
# Strategy:
#   1. Parse the Class-Path from local-starter-*.jar MANIFEST.MF — this is the
#      canonical list of JAR filenames (with exact versions and classifiers) that
#      the app was built against.
#   2. For each JAR in the extracted dir, SHA1-search Maven Central to get the
#      groupId, but use the version and classifier from the manifest filename
#      (more accurate than the SHA1 result, which loses classifiers).
#   3. JARs not found on Maven Central → keep in lib.tar.gz.
#
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
import re
import zipfile
import urllib.request
import urllib.parse
import xml.etree.ElementTree as ET
from pathlib import Path

jars_dir = Path(sys.argv[1])
pom_path = sys.argv[2]

NS = "http://maven.apache.org/POM/4.0.0"
ET.register_namespace("", NS)
ET.register_namespace("xsi", "http://www.w3.org/2001/XMLSchema-instance")


# ── Manifest parsing ──────────────────────────────────────────────────────────

def parse_manifest_classpath(jars_dir):
    """Return dict {jar_basename: (version, classifier)} from local-starter manifest."""
    starter_jars = sorted(jars_dir.glob("local-starter-*.jar"))
    if not starter_jars:
        print("  WARN: no local-starter-*.jar found; falling back to SHA1-only mode",
              file=sys.stderr)
        return {}

    starter_jar = starter_jars[0]
    try:
        with zipfile.ZipFile(starter_jar) as zf:
            with zf.open("META-INF/MANIFEST.MF") as mf:
                content = mf.read().decode("utf-8", errors="replace")
    except Exception as e:
        print(f"  WARN: could not read manifest from {starter_jar.name}: {e}",
              file=sys.stderr)
        return {}

    # MANIFEST.MF folds long headers with " " continuation lines
    lines = content.splitlines()
    classpath_tokens = []
    in_cp = False
    for line in lines:
        if line.startswith("Class-Path:"):
            in_cp = True
            classpath_tokens.append(line[len("Class-Path:"):].strip())
        elif in_cp and line.startswith(" "):
            classpath_tokens.append(line[1:])
        elif in_cp:
            break

    classpath = " ".join(classpath_tokens)
    result = {}
    for entry in classpath.split():
        if not entry.endswith(".jar"):
            continue
        version, classifier = _parse_filename(entry)
        if version:
            result[entry] = (version, classifier)

    print(f"Parsed {len(result)} entries from {starter_jar.name} manifest")
    return result


def _parse_filename(basename):
    """
    Parse 'artifactId-version[-classifier].jar' → (version, classifier).
    Returns ("", "") if no version token found.
    """
    name = basename[:-4]          # strip .jar
    parts = name.split("-")
    for i, part in enumerate(parts):
        if re.match(r'^\d+(\.\d+)*$', part):
            version = part
            classifier = "-".join(parts[i + 1:])
            return version, classifier
    return "", ""


# ── Maven Central helpers ─────────────────────────────────────────────────────

def sha1_of(path):
    h = hashlib.sha1()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def search_by_sha1(sha1):
    """Return (groupId, artifactId) if found on Maven Central, else None."""
    q = urllib.parse.quote(f'1:"{sha1}"')
    url = f'https://search.maven.org/solrsearch/select?q={q}&rows=1&wt=json'
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "sync-deps/2.0"})
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read())
        docs = data.get("response", {}).get("docs", [])
        if docs:
            d = docs[0]
            return d["g"], d["a"]
    except Exception as e:
        print(f"  WARN: Maven Central query failed: {e}", file=sys.stderr)
    return None


# ── pom.xml helpers ───────────────────────────────────────────────────────────

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


def add_dependency(root, group_id, artifact_id, version, classifier=""):
    deps = root.find(f".//{{{NS}}}dependencies")
    dep = ET.SubElement(deps, f"{{{NS}}}dependency")
    ET.SubElement(dep, f"{{{NS}}}groupId").text = group_id
    ET.SubElement(dep, f"{{{NS}}}artifactId").text = artifact_id
    ET.SubElement(dep, f"{{{NS}}}version").text = version
    if classifier:
        ET.SubElement(dep, f"{{{NS}}}classifier").text = classifier
    excls = ET.SubElement(dep, f"{{{NS}}}exclusions")
    excl = ET.SubElement(excls, f"{{{NS}}}exclusion")
    ET.SubElement(excl, f"{{{NS}}}groupId").text = "*"
    ET.SubElement(excl, f"{{{NS}}}artifactId").text = "*"
    coord = f"{group_id}:{artifact_id}:{version}"
    if classifier:
        coord += f":{classifier}"
    print(f"  + Added to pom.xml: {coord}")


# ── Main ──────────────────────────────────────────────────────────────────────

manifest_info = parse_manifest_classpath(jars_dir)  # {basename: (version, classifier)}

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
        group_id, artifact_id = result

        # Use version/classifier from manifest (authoritative) if available;
        # fall back to filename parsing of the actual file.
        if jar.name in manifest_info:
            version, classifier = manifest_info[jar.name]
        else:
            version, classifier = _parse_filename(jar.name)

        if not version:
            print(f"found on Maven Central but could not parse version — keeping in lib/")
            keep_in_lib.append(jar)
            continue

        coord = f"{group_id}:{artifact_id}:{version}"
        if classifier:
            coord += f":{classifier}"
        print(f"found ({coord})")

        if not dep_exists(root, group_id, artifact_id):
            add_dependency(root, group_id, artifact_id, version, classifier)
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

with open("lib-keep.txt", "w") as f:
    for jar in keep_in_lib:
        f.write(str(jar) + "\n")
PYEOF

echo "Done. JARs to keep in lib/ listed in lib-keep.txt"
