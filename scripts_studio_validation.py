"""Render a developer-only local plugin for the disposable Studio Baseplate.

ChangeHistoryService recordings require plugin context. The command rendering is
also retained for diagnosis, but must not be mistaken for a supported test entry.
"""
from pathlib import Path

root = Path(__file__).resolve().parent
template = (root / 'tests/studio/OwnershipValidation.template.luau').read_text(encoding='utf-8')
assert template.count('__RUNNER_MANAGER__') == 1
manager = (root / 'src/RunnerManager.luau').read_text(encoding='utf-8')
rendered = template.replace('__RUNNER_MANAGER__', '(function()\n' + manager + '\nend)()')
destination = root / '.tools/studio-validation/ownership-validation.command.luau'
destination.parent.mkdir(parents=True, exist_ok=True)
destination.write_text(rendered, encoding='utf-8', newline='\n')
print(destination)
plugin_source = '''-- Developer-only local validation plugin. Never publish.
local toolbar = plugin:CreateToolbar("RA Validation")
local button = toolbar:CreateButton("Validate ownership", "Run real engine ownership checks in the disposable Baseplate", "")
button.Click:Connect(function()
    local ok, reason = pcall(function()
''' + rendered + '''
    end)
    if not ok then warn("RA_VALIDATION ST11 ERROR", reason) end
end)
'''
plugin_destination = destination.with_name('ownership-validation.plugin.luau')
plugin_destination.write_text(plugin_source, encoding='utf-8', newline='\n')
print(plugin_destination)
