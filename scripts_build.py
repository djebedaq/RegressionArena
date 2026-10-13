"""Build a single-file Roblox plugin from version-controlled components."""
from pathlib import Path
ROOT = Path(__file__).resolve().parent
runner = (ROOT / 'src/TestRunner.server.luau').read_text()
template = (ROOT / 'src/RegressionArena.plugin.template.luau').read_text()
assert '__EMBEDDED_RUNNER_SOURCE__' in template
assert ']==]' not in runner, 'Embedded Luau closing delimiter collision'
rendered = template.replace('__EMBEDDED_RUNNER_SOURCE__', '[==[\n' + runner + '\n]==]')
out = ROOT / 'dist/RegressionArena.plugin.luau'
out.parent.mkdir(exist_ok=True)
out.write_text(rendered)
print(out)
