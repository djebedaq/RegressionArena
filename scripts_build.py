"""Deterministically package the offline plugin. No engine execution is performed."""
from pathlib import Path
import hashlib
import json
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent


def substitute(template: str, marker: str, value: str) -> str:
    if template.count(marker) != 1:
        raise ValueError(f"Expected exactly one {marker}")
    return template.replace(marker, value)


def module(source: str) -> str:
    return "(function()\n" + source + "\nend)()"


def render_runner(sources: dict[str, str]) -> str:
    protocol = module(sources["Protocol.luau"])
    runner = substitute(sources["TestRunner.server.luau"], "__PROTOCOL__", protocol)
    runner = substitute(runner, "__RUNNER_CORE__", module(sources["RunnerCore.luau"]))
    runner = substitute(runner, "__SNAPSHOT__", module(sources["Snapshot.luau"]))
    runner = substitute(runner, "__INSTANCE_READER__", module(sources["InstanceReader.luau"]))
    return runner


def render(sources: dict[str, str]) -> str:
    protocol = module(sources["Protocol.luau"])
    runner = render_runner(sources)
    if "]==]" in runner:
        raise ValueError("Embedded Luau closing delimiter collision")
    plugin = substitute(sources["RegressionArena.plugin.template.luau"], "__PROTOCOL__", protocol)
    plugin = substitute(plugin, "__RUNNER_MANAGER__", module(sources["RunnerManager.luau"]))
    plugin = substitute(plugin, "__SESSION__", module(sources["Session.luau"]))
    plugin = substitute(plugin, "__SETTINGS__", module(sources["Settings.luau"]))
    plugin = substitute(plugin, "__SNAPSHOT__", module(sources["Snapshot.luau"]))
    plugin = substitute(plugin, "__INTERFACE__", module(sources["Interface.luau"]))
    plugin = substitute(plugin, "__SNAPSHOT_UI__", module(sources["SnapshotUI.luau"]))
    return substitute(plugin, "__EMBEDDED_RUNNER_SOURCE__", "[==[\n" + runner + "\n]==]")


def build(root: Path = ROOT) -> Path:
    sources = {path.name: path.read_text(encoding="utf-8") for path in (root / "src").glob("*.luau")}
    rendered = render(sources)
    out = root / "dist/RegressionArena.plugin.luau"
    out.parent.mkdir(exist_ok=True)
    out.write_text(rendered, encoding="utf-8", newline="\n")
    # A standalone Studio asset: one readable plugin Script, no developer fixtures.
    asset = ET.Element("roblox", {"version": "4"})
    ET.SubElement(asset, "External").text = "null"
    ET.SubElement(asset, "External").text = "nil"
    item = ET.SubElement(asset, "Item", {"class": "Script", "referent": "RBXRegressionArena"})
    props = ET.SubElement(item, "Properties")
    ET.SubElement(props, "bool", {"name": "Disabled"}).text = "false"
    ET.SubElement(props, "token", {"name": "RunContext"}).text = "0"
    ET.SubElement(props, "string", {"name": "Name"}).text = "RegressionArena"
    ET.SubElement(props, "ProtectedString", {"name": "Source"}).text = rendered
    asset_bytes = ET.tostring(asset, encoding="utf-8", xml_declaration=True) + b"\n"
    (out.parent / "RegressionArena.rbxmx").write_bytes(asset_bytes)
    manifest = {"product": "Regression Arena", "version": "1.0.0", "status": "release candidate",
                "supportedConfiguration": "one initial player; latejoin to two clients",
                "files": {out.name: hashlib.sha256(out.read_bytes()).hexdigest(),
                          "RegressionArena.rbxmx": hashlib.sha256(asset_bytes).hexdigest()}}
    (out.parent / "RegressionArena.package.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8", newline="\n")
    return out


if __name__ == "__main__":
    print(build())
