"""Deterministically package the offline plugin. No engine execution is performed."""
from pathlib import Path

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
    return substitute(plugin, "__EMBEDDED_RUNNER_SOURCE__", "[==[\n" + runner + "\n]==]")


def build(root: Path = ROOT) -> Path:
    sources = {path.name: path.read_text(encoding="utf-8") for path in (root / "src").glob("*.luau")}
    rendered = render(sources)
    out = root / "dist/RegressionArena.plugin.luau"
    out.parent.mkdir(exist_ok=True)
    out.write_text(rendered, encoding="utf-8", newline="\n")
    return out


if __name__ == "__main__":
    print(build())
