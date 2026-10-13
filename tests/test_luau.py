"""Execute real Luau modules with mocked services, never the Roblox engine.

Install official Luau 0.742 or set LUAU_BIN and LUAU_COMPILE_BIN. CI requires both.
Plain Python build/integrity checks remain usable when these optional developer tools
are absent; any skipped mock/compiler cases are explicitly visible in unittest output.
"""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import unittest

from scripts_build import render_runner
from test_package import sources

ROOT = Path(__file__).resolve().parents[1]


def executable(env_name, name):
    explicit = os.environ.get(env_name)
    if explicit:
        return explicit
    found = shutil.which(name)
    if found:
        return found
    local = ROOT / ".tools" / "luau" / (name + (".exe" if os.name == "nt" else ""))
    return str(local) if local.is_file() else None


LUAU = executable("LUAU_BIN", "luau")
COMPILER = executable("LUAU_COMPILE_BIN", "luau-compile")


class LuauChecks(unittest.TestCase):
    def run_script(self, script):
        if not LUAU:
            self.skipTest("Luau CLI unavailable; mock execution NOT RUN")
        result = subprocess.run([LUAU, str(script)], cwd=ROOT, capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("MOCK TESTS:", result.stdout)
        print("\n" + result.stdout.strip())

    def test_protocol_contracts(self):
        self.run_script(ROOT / "tests/luau/Protocol.spec.luau")

    def test_local_history_bounds_and_sanitization(self):
        self.run_script(ROOT / "tests/luau/Settings.spec.luau")

    def test_runner_scenarios(self):
        self.run_script(ROOT / "tests/luau/RunnerCore.spec.luau")

    def test_session_timeout_cancellation_and_recovery(self):
        self.run_script(ROOT / "tests/luau/Session.spec.luau")

    def test_install_remove_ownership_and_rollback(self):
        self.run_script(ROOT / "tests/luau/RunnerManager.spec.luau")

    def test_generated_server_boundary_with_mock_services(self):
        template = (ROOT / "tests/luau/RunnerBoundary.spec.luau").read_text(encoding="utf-8")
        with tempfile.NamedTemporaryFile(mode="w", suffix=".luau", dir=ROOT / "tests/luau",
                                         encoding="utf-8", delete=False) as file:
            path = Path(file.name)
            file.write(template.replace("__RUNNER_UNDER_TEST__", render_runner(sources())))
        try:
            self.run_script(path)
        finally:
            path.unlink()

    def test_all_modules_and_both_generated_contexts_compile(self):
        if not COMPILER:
            self.skipTest("Luau compiler unavailable; syntax checks NOT RUN")
        scripts = list((ROOT / "src").glob("*.luau")) + [ROOT / "dist/RegressionArena.plugin.luau"]
        with tempfile.TemporaryDirectory() as directory:
            runner = Path(directory) / "runner.luau"
            runner.write_text(render_runner(sources()), encoding="utf-8")
            for script in scripts + [runner]:
                with self.subTest(script=script.name):
                    result = subprocess.run([COMPILER, "--null", str(script)], cwd=ROOT,
                                            capture_output=True, text=True, timeout=30)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
