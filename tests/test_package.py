"""Build and packaging checks; these are not Roblox Studio execution tests."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from scripts_build import build, render, render_runner, substitute

ROOT = Path(__file__).resolve().parents[1]


def sources():
    return {path.name: path.read_text(encoding="utf-8") for path in (ROOT / "src").glob("*.luau")}


class BuildChecks(unittest.TestCase):
    def test_generated_matches_source_exactly(self):
        self.assertEqual((ROOT / "dist/RegressionArena.plugin.luau").read_bytes(), render(sources()).encode("utf-8"))

    def test_build_is_byte_deterministic_and_lf_utf8(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "src").mkdir()
            for name, content in sources().items():
                (root / "src" / name).write_text(content, encoding="utf-8", newline="\r\n")
            first = build(root).read_bytes()
            self.assertEqual(first, build(root).read_bytes())
            self.assertNotIn(b"\r", first)
            self.assertFalse(first.startswith(b"\xef\xbb\xbf"))

    def test_build_cli_runs_from_unrelated_directory(self):
        with tempfile.TemporaryDirectory() as directory:
            result = subprocess.run([sys.executable, str(ROOT / "scripts_build.py")], cwd=directory,
                                    capture_output=True, text=True, check=True)
        self.assertIn("RegressionArena.plugin.luau", result.stdout)

    def test_missing_or_duplicate_markers_fail_build(self):
        for marker in ("__PROTOCOL__", "__RUNNER_MANAGER__", "__SESSION__", "__SETTINGS__", "__EMBEDDED_RUNNER_SOURCE__"):
            for replacement in ("", marker + marker):
                with self.subTest(marker=marker, replacement=replacement):
                    files = sources()
                    files["RegressionArena.plugin.template.luau"] = files["RegressionArena.plugin.template.luau"].replace(marker, replacement)
                    with self.assertRaisesRegex(ValueError, "Expected exactly one"):
                        render(files)
        for marker in ("__PROTOCOL__", "__RUNNER_CORE__"):
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
