"""Structural guardrails only. Real Studio behavior is covered by the manual checklist."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class IntegrityChecks(unittest.TestCase):
    def test_published_and_client_guards_precede_test_service_access(self):
        runner = (ROOT / "src/TestRunner.server.luau").read_text(encoding="utf-8")
        self.assertLess(runner.index("if not RunService:IsStudio() or not RunService:IsServer() then return end"),
                        runner.index('game:GetService("StudioTestService")'))
        self.assertLess(runner.index("not contract.validRequest(request) then return end"), runner.index("task.delay("))

    def test_no_external_network_dynamic_code_or_game_data_access(self):
        source = "\n".join(path.read_text(encoding="utf-8") for path in (ROOT / "src").glob("*.luau"))
        for forbidden in ("GetAsync(", "PostAsync(", "RequestAsync(", "loadstring(", "game:HttpGet(",
                          "DataStoreService", "MarketplaceService", "InsertService", "UserId", "DisplayName"):
            with self.subTest(forbidden=forbidden):
                self.assertNotIn(forbidden, source)

    def test_source_mutation_is_limited_to_off_tree_candidate(self):
        source = "\n".join(path.read_text(encoding="utf-8") for path in (ROOT / "src").glob("*.luau"))
        writes = [line.strip() for line in source.splitlines() if ".Source =" in line]
        self.assertEqual(writes, ["candidate.Source = source"])

    def test_cleanup_never_calls_client_only_leave_or_persists_simulation(self):
        source = "\n".join(path.read_text(encoding="utf-8") for path in (ROOT / "src").glob("*.luau"))
        for forbidden in (":CanLeaveTest(", ":LeaveTest(", "RunService:Stop("):
            with self.subTest(forbidden=forbidden):
                self.assertNotIn(forbidden, source)

    def test_ci_requires_build_clean_generated_diff_and_luau(self):
        workflow = (ROOT / ".github/workflows/python-checks.yml").read_text(encoding="utf-8")
        for required in ("python scripts_build.py", "python -m unittest discover -s tests -v",
                         "git diff --exit-code -- dist/", "LUAU_BIN", "LUAU_COMPILE_BIN", "sha256sum --check"):
            self.assertIn(required, workflow)


if __name__ == "__main__":
    unittest.main()
