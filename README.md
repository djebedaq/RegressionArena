# Regression Arena — prototype v0.1

**Status:** source-code MVP, not yet validated in Roblox Studio or approved for Creator Store sale.

A fully local Roblox Studio plugin for simple multiplayer smoke testing.
Uses the official `StudioTestService` API. No subscription, server or AI key.

## What works in the source
- One-click installation of a versioned server-side test runner in `ServerScriptService`.
- Player options: 1, 2, 4.
- Tests: simultaneous join, character spawn with Humanoid, late join.
- Returns PASS/FAIL, explanations, latency, JSON report.
- Saves last ten results in the plugin's local settings.
- Never performs external network requests or changes published game servers.

## Try it in Roblox Studio (manual runtime validation required)
1. Download `dist/RegressionArena.plugin.luau` from this archive.
2. In Roblox Studio, open a **copy** of a simple testing place. Enable **Plugin Debugging Enabled** in Studio settings.
3. Under `ServerStorage`, create a `Script` named `RegressionArena` and replace its Source with the contents of `dist/RegressionArena.plugin.luau`.
4. Select the script, then choose **Plugins > Save as Local Plugin**.
5. Open the new plugin via the toolbar (it appears in `PluginDebugService`). Delete the original script from `ServerStorage` after saving.
6. Click **Install / update test runner**, select 2 players, and click **Run 3 test scenarios**.
7. Confirm each test session exits automatically and that a PASS/FAIL summary is displayed.
8. Repeat on a place with `Players.CharacterAutoLoads=false` to verify `spawn` correctly fails or times out rather than claiming success.

**Note:** The installed runner lives in `ServerScriptService`; it does not run in published servers because of the `RunService:IsStudio()` guard. Remove the runner script when you no longer need it. It is shipped with the place if left there, even though it returns immediately outside Studio.

## Developer commands

```bash
python scripts_build.py
python -m unittest discover -s tests -v
```

## What is NOT ready
- No actual Roblox Studio execution was possible in this environment.
- The embedded runner's `StudioTestService:AddPlayers()` path and cross-context serialization must be exercised in Studio.
- No tests for game-specific RemoteEvents, purchases, combat, matchmaking, or data stores.
- No paid seller listing, identity checks, payout setup, images, or review approval.

## Source references
- https://create.roblox.com/docs/reference/engine/classes/StudioTestService
- https://create.roblox.com/docs/studio/plugins
- https://create.roblox.com/docs/production/creator-store

## Codex handoff

This archive is ready to be put in a **new private GitHub repository** and opened as a Codex coding task.

- Start with `CODEX_START_HERE.md` (copy that file as the Codex prompt).
- `AGENTS.md` tells Codex how to work in this codebase.
- `docs/CODEX_TASK.md` defines the v0.2 deliverables and acceptance criteria.
- `docs/STUDIO_VALIDATION.md` contains manual Roblox Studio acceptance tests.
- `.github/workflows/python-checks.yml` runs build and *structural* tests on commits.

The current Python test suite verifies source packaging and guardrails only. **No Roblox Studio run has been performed and this is not ready for sale.**
