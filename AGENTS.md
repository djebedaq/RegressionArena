# Instructions for Codex — Regression Arena

You are working on **Regression Arena**, an offline Roblox Studio plugin for repeatable multiplayer smoke testing. The developer is building a paid Creator Store product. Treat reliability and real user value as higher priority than cosmetic features.

## Read first

1. `README.md`
2. `docs/CODEX_TASK.md`
3. `docs/STUDIO_VALIDATION.md`
4. Official Roblox StudioTestService API: https://create.roblox.com/docs/reference/engine/classes/StudioTestService
5. Official Roblox plugins guide: https://create.roblox.com/docs/studio/plugins

## Development rules

- **Never assert a Roblox Studio runtime test passed if you did not run Roblox Studio.** Static Python tests are build/integrity checks, not execution tests.
- Do not fabricate APIs, permissions, sales, test logs, or successful execution.
- No credentials, third-party AI API, telemetry, remote HTTP endpoints, server subscription, or payment/licensing system in v0.2.
- Never modify or destroy customers' game content or player data. Any installation to `ServerScriptService` must be explicit, clearly named, versioned, reversible and inert in published games. Prefer an optional uninstall action.
- Use Roblox Studio APIs and Luau idioms. Distinguish plugin, server, and client contexts; validate API access to each context against official docs.
- `src/` contains source of truth. `dist/RegressionArena.plugin.luau` is generated. Rebuild via `python scripts_build.py`; never edit generated code manually.
- Follow minimal dependency and offline-first principles. Keep all local-only outputs and settings bounded in size.
- Every bug fix should receive an appropriate regression check or a documented manual Studio test.
- Keep feature scope narrow. Prioritize robust start/end, accurate reporting, and a reproducible demo over optional AI features.

## Before proposing a PR

Run:

```bash
python scripts_build.py
python -m unittest discover -s tests -v
```

Report:
- Which files changed and why.
- What tests actually ran and their exact outcomes.
- What could *not* be verified outside Roblox Studio.
- Exact manual Studio test steps and known unresolved risks.

Do not publish to Creator Store, change payment accounts, or alter unrelated repositories.
