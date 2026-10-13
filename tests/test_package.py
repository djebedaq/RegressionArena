from pathlib import Path
import subprocess
import sys
import unittest
ROOT = Path(__file__).resolve().parents[1]

class BuildSmokeTest(unittest.TestCase):
    def test_build_embeds_runner(self):
        subprocess.run([sys.executable, str(ROOT / 'scripts_build.py')], check=True, capture_output=True)
        plugin = (ROOT / 'dist/RegressionArena.plugin.luau').read_text()
        self.assertIn('ExecuteMultiplayerTestAsync', plugin)
        self.assertIn('GetTestArgs()', plugin)
        self.assertIn('StudioTestService:EndTest', plugin)
        self.assertIn('ChangeHistoryService:SetWaypoint', plugin)
        self.assertNotIn('__EMBEDDED_RUNNER_SOURCE__', plugin)
    def test_no_network(self):
        for path in (ROOT / 'src').glob('*.luau'):
            self.assertNotIn('HttpService:GetAsync', path.read_text())
            self.assertNotIn('HttpService:PostAsync', path.read_text())
            self.assertNotIn('loadstring(', path.read_text())

if __name__ == '__main__': unittest.main()
