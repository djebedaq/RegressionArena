from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class IntegrityChecks(unittest.TestCase):
    def test_generated_is_exact_deterministic_render(self):
        runner = (ROOT / 'src' / 'TestRunner.server.luau').read_text()
        template = (ROOT / 'src' / 'RegressionArena.plugin.template.luau').read_text()
        generated = (ROOT / 'dist' / 'RegressionArena.plugin.luau').read_text()
        self.assertNotIn(']==]', runner, 'Runner would break Luau long-string delimiter')
        self.assertEqual(template.count('__EMBEDDED_RUNNER_SOURCE__'), 1)
        self.assertEqual(generated, template.replace('__EMBEDDED_RUNNER_SOURCE__', '[==[\n' + runner + '\n]==]'))

    def test_runner_has_studio_guard_and_nonmatching_args_exit(self):
        runner = (ROOT / 'src' / 'TestRunner.server.luau').read_text()
        self.assertIn('RunService:IsStudio()', runner)
        self.assertIn('if not RunService:IsStudio() then', runner)
        self.assertIn('StudioTestService:GetTestArgs()', runner)
        self.assertIn('if not scenario then', runner)
        self.assertIn('StudioTestService:EndTest', runner)

    def test_no_external_network_or_code_downloads(self):
        source = '\n'.join(path.read_text() for path in (ROOT / 'src').glob('*.luau'))
        for forbidden in ['HttpService:GetAsync(', 'HttpService:PostAsync(', 'RequestAsync(', 'loadstring(', 'require(http', 'game:HttpGet(']:
            with self.subTest(forbidden=forbidden):
                self.assertNotIn(forbidden, source)


if __name__ == '__main__':
    unittest.main()
