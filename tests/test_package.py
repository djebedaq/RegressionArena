"""Build and packaging checks; these are not Roblox Studio execution tests."""
from pathlib import Path
import subprocess
import hashlib
import json
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET
import zipfile

from scripts_build import build, render, render_runner, substitute
from scripts_release import package

ROOT = Path(__file__).resolve().parents[1]


def sources():
    return {path.name: path.read_text(encoding="utf-8") for path in (ROOT / "src").glob("*.luau")}


class BuildChecks(unittest.TestCase):
    def test_buyer_zip_is_deterministic_exact_and_excludes_developer_files(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "buyer.zip"
            package(ROOT, path)
            first = path.read_bytes()
            with zipfile.ZipFile(path) as archive:
                self.assertEqual(set(archive.namelist()), {
                    "RegressionArena.rbxmx", "RegressionArena-Demo.rbxlx",
                    "BUYER_GUIDE.md", "README.txt", "manifest.json"})
                manifest = json.loads(archive.read("manifest.json"))
                for name, digest in manifest["files"].items():
                    self.assertEqual(hashlib.sha256(archive.read(name)).hexdigest(), digest)
                self.assertEqual(archive.read("RegressionArena.rbxmx"), (ROOT / "dist/RegressionArena.rbxmx").read_bytes())
            package(ROOT, path)
            self.assertEqual(first, path.read_bytes())

    def test_standalone_asset_contains_only_the_exact_plugin_source(self):
        asset = ET.parse(ROOT / "dist/RegressionArena.rbxmx").getroot()
        items = asset.findall(".//Item")
        self.assertEqual(len(items), 1)
        self.assertEqual(items[0].get("class"), "Script")
        self.assertEqual(items[0].find("./Properties/ProtectedString[@name='Source']").text,
                         render(sources()))
        self.assertEqual(items[0].find("./Properties/bool[@name='Disabled']").text, "false")

    def test_generated_matches_source_exactly(self):
        self.assertEqual((ROOT / "dist/RegressionArena.plugin.luau").read_bytes(), render(sources()).encode("utf-8"))

    def test_build_is_byte_deterministic_and_lf_utf8(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "src").mkdir()
            for name, content in sources().items():
                (root / "src" / name).write_text(content, encoding="utf-8", newline="\r\n")
            first = build(root).read_bytes()
            first_package = {p.name: p.read_bytes() for p in (root / "dist").iterdir()}
            self.assertEqual(first, build(root).read_bytes())
            self.assertEqual(first_package, {p.name: p.read_bytes() for p in (root / "dist").iterdir()})
            self.assertNotIn(b"\r", first)
            self.assertFalse(first.startswith(b"\xef\xbb\xbf"))

    def test_build_cli_runs_from_unrelated_directory(self):
        with tempfile.TemporaryDirectory() as directory:
            result = subprocess.run([sys.executable, str(ROOT / "scripts_build.py")], cwd=directory,
                                    capture_output=True, text=True, check=True)
        self.assertIn("RegressionArena.plugin.luau", result.stdout)

    def test_missing_or_duplicate_markers_fail_build(self):
        for marker in ("__PROTOCOL__", "__RUNNER_MANAGER__", "__SESSION__", "__SETTINGS__", "__SNAPSHOT__", "__INTERFACE__", "__SNAPSHOT_UI__", "__EMBEDDED_RUNNER_SOURCE__"):
            for replacement in ("", marker + marker):
                with self.subTest(marker=marker, replacement=replacement):
                    files = sources()
                    files["RegressionArena.plugin.template.luau"] = files["RegressionArena.plugin.template.luau"].replace(marker, replacement)
                    with self.assertRaisesRegex(ValueError, "Expected exactly one"):
                        render(files)
        for marker in ("__PROTOCOL__", "__RUNNER_CORE__", "__SNAPSHOT__", "__INSTANCE_READER__"):
            files = sources()
            files["TestRunner.server.luau"] = files["TestRunner.server.luau"].replace(marker, "")
            with self.assertRaises(ValueError):
                render(files)

    def test_runner_delimiter_collision_is_rejected(self):
        files = sources()
        files["RunnerCore.luau"] += "\n-- ]==]"
        with self.assertRaisesRegex(ValueError, "delimiter collision"):
            render(files)

    def test_embedded_runner_is_exact_complete_render(self):
        generated = render(sources())
        embedded = generated.split("local RUNNER_SOURCE = [==[\n", 1)[1].split("\n]==]", 1)[0]
        self.assertEqual(embedded, render_runner(sources()))
        for marker in ("__PROTOCOL__", "__RUNNER_CORE__", "__SESSION__", "__EMBEDDED_RUNNER_SOURCE__"):
            self.assertNotIn(marker, generated)

    def test_marker_replacement_does_not_silently_accept_multiple_targets(self):
        with self.assertRaises(ValueError):
            substitute("X X", "X", "value")


if __name__ == "__main__":
    unittest.main()
