#!/bin/sh
# Build a .plasmoid file (zip of package/) for uploading to the KDE Store.
set -e
cd "$(dirname "$0")"
python3 -I - <<'PY'
import json, os, zipfile
version = json.load(open("package/metadata.json"))["KPlugin"]["Version"]
out = f"kde-screenrotate-{version}.plasmoid"
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for dirpath, _, files in os.walk("package"):
        for f in sorted(files):
            path = os.path.join(dirpath, f)
            z.write(path, os.path.relpath(path, "package"))
print("Built", out)
PY
