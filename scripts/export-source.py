#!/usr/bin/env python3
"""Export only reviewed source paths; never package the developer checkout."""
import hashlib
import json
from pathlib import Path
import shutil
import tempfile
import zipfile

root = Path(__file__).resolve().parent.parent
version = "0.10.4"
name = f"BailongMac-{version}-source"
allowed = [
    ".gitignore", "Package.swift", "README.md", "LICENSE.md", "NOTICE.md",
    "THIRD_PARTY_NOTICES.md", "CONTRIBUTING.md", "CHANGELOG.md", "LICENSES",
    "Sources", "Tests", "scripts", "Resources/Public", ".github/workflows/ci.yml",
    "docs/PRIVACY.md", "docs/ASSETS.md", "docs/DEVELOPMENT.md", "docs/upstream",
]
(root / "work").mkdir(exist_ok=True)
stage = Path(tempfile.mkdtemp(prefix="public-source-", dir=root / "work")) / name
stage.mkdir()
for entry in allowed:
    source = root / entry
    paths = sorted(source.rglob("*")) if source.is_dir() else [source]
    for path in paths:
        if path.is_symlink():
            raise SystemExit(f"Refusing symlink: {path.relative_to(root)}")
        if not path.is_file() or path.name == ".DS_Store":
            continue
        target = stage / path.relative_to(root)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, target)

manifest = {}
for path in sorted(stage.rglob("*")):
    if not path.is_file():
        continue
    relative = path.relative_to(stage).as_posix()
    data = path.read_bytes()
    if (b"/" + b"Users/") in data or path.suffix in {".jsonl", ".pem", ".key"}:
        raise SystemExit(f"Private path or forbidden file in export: {relative}")
    manifest[relative] = hashlib.sha256(data).hexdigest()
(stage / "SOURCE_MANIFEST.json").write_text(json.dumps(manifest, indent=2) + "\n")
destination = root / "outputs" / f"{name}.zip"
destination.parent.mkdir(exist_ok=True)
temporary = destination.with_suffix(".zip.tmp")
with zipfile.ZipFile(temporary, "w", zipfile.ZIP_DEFLATED) as archive:
    for path in sorted(stage.rglob("*")):
        if path.is_file():
            archive.write(path, path.relative_to(stage.parent))
temporary.replace(destination)
print(json.dumps({"source": str(stage), "zip": str(destination), "files": len(manifest)}, ensure_ascii=False))
