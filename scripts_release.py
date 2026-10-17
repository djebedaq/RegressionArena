"""Create a deterministic buyer bundle. This does not upload or publish anything."""
from pathlib import Path
import hashlib
import json
import zipfile
import xml.etree.ElementTree as ET

from scripts_build import ROOT, build

VERSION = "1.0.0"
CONTENTS = {
    "RegressionArena.rbxmx": "dist/RegressionArena.rbxmx",
    "RegressionArena-Demo.rbxlx": "demo/RegressionArena-Demo.rbxlx",
    "BUYER_GUIDE.md": "release/BUYER_GUIDE.md",
}
README = """Regression Arena 1.0.0 — release candidate

Read BUYER_GUIDE.md before testing. Use a disposable local place copy.

Local installation: open RegressionArena.rbxmx in Roblox Studio, select its single
RegressionArena Script, then Plugins > Save as Local Plugin. Close the asset
without saving changes. Open a copy of the demo place and install the runner from
the plugin's Setup tab. Load the bundled demonstration plan from Snapshot.

Creator Store upload, after explicit owner approval: select only that plugin
Script, then Publish as Plugin. The ZIP and demonstration place are not plugins.
This bundle does not establish seller approval or authorize publication.

Supported: one initial player; Smoke latejoin to two clients. Server-state checks
only. Up to 16 explicit assertions, one local plan and baseline slot. No guarantee
of finding every bug. Remove the runner before shipping your game. Update by
removing the runner with the old matching plugin before replacing that plugin.

All bundle files are listed with SHA-256 hashes in manifest.json. No developer
fixtures, test scripts, debug tools or remote dependencies are distributed here.
"""


def package(root: Path = ROOT, destination: Path | None = None) -> Path:
    build(root)
    files = {name: (root / path).read_bytes() for name, path in CONTENTS.items()}
    plugin = ET.fromstring(files["RegressionArena.rbxmx"])
    items = plugin.findall(".//Item")
    if len(items) != 1 or items[0].get("class") != "Script":
        raise ValueError("Production plugin must contain exactly one Script")
    demo = ET.fromstring(files["RegressionArena-Demo.rbxlx"])
    if any(item.get("class") in {"Script", "LocalScript", "ModuleScript"} for item in demo.iter("Item")):
        raise ValueError("Distribution demo must not contain executable scripts or runner fixtures")
    files["README.txt"] = README.encode("utf-8")
    manifest = {"product": "Regression Arena", "version": VERSION,
                "status": "release candidate; owner approval required",
                "pluginSourceSHA256": hashlib.sha256((root / "dist/RegressionArena.plugin.luau").read_bytes()).hexdigest(),
                "supportedConfiguration": "one initial player; latejoin to two clients",
                "files": {name: hashlib.sha256(content).hexdigest() for name, content in sorted(files.items())}}
    files["manifest.json"] = (json.dumps(manifest, indent=2) + "\n").encode("utf-8")
    out = destination or root / f"dist/RegressionArena-{VERSION}.zip"
    # Stored entries also remain identical across different zlib/Python releases.
    with zipfile.ZipFile(out, "w", compression=zipfile.ZIP_STORED) as archive:
        for name, content in sorted(files.items()):
            info = zipfile.ZipInfo(name, date_time=(2026, 10, 17, 0, 0, 0))
            info.compress_type = zipfile.ZIP_STORED
            info.create_system = 3
            info.external_attr = 0o100644 << 16
            archive.writestr(info, content)
    return out


if __name__ == "__main__":
    print(package())
