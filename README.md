# Regression Arena — v0.2 prototype

**Status: RA-001 implementation; Roblox Studio runtime validation remains UNVERIFIED. Not production-ready or approved for sale.**

Regression Arena runs repeatable multiplayer smoke checks in a local Roblox Studio place copy. Select `join`, `spawn`, and `latejoin` independently, choose 1/2/4 initial players, and give each case a whole-number timeout of 5–60 seconds (default 20). Each case starts its own multiplayer session. Latejoin requests one additional player after the initial group joins.

A PASS requires a matching run identifier, strict result schema, and scenario evidence. Reports include expected/observed behavior, elapsed seconds, counts, and a suggested next check. A timed-out, cancelled, malformed, or stale result cannot become PASS. Infrastructure failure aborts the remaining cases with explicit “not run” failures.

## Install and run locally

1. Open a **disposable, local copy** of a simple place. Game scripts still execute during tests; keep production credentials, live data access, purchases, and external integrations out of this copy. Regression Arena does not intercept game code or sandbox its side effects.
2. Enable **Plugin Debugging Enabled** in Studio settings. Insert a temporary `Script` named `RegressionArena` under `ServerStorage`; paste `dist/RegressionArena.plugin.luau` into its Source.
3. Select it and use **Plugins → Save as Local Plugin**. Delete the temporary Script. Open Regression Arena using its toolbar button.
4. In edit mode, click **Install / update owned test runner**. The sole place asset created is `ServerScriptService.RegressionArena_TestRunner`, with `RAOwner=RegressionArena`, `RAVersion=0.2.0`, and server Legacy run context. Installation/removal use undo recordings.
5. Select the player count, toggle cases, and enter the timeout under each case. Click **Run selected test plan**. The vertically scrolling panel remains usable in a small dock.
6. Inspect the counts and diagnosis. Click Results and use Ctrl+A / Ctrl+C to copy text and JSON. **Show last saved report** is explicitly labeled as a previous run.
7. **Save local preset** / **Load local preset** retain one plan in plugin settings, without adding game assets. History retains at most ten reports, each at most 8 KiB. The preset is at most 2 KiB when loaded. Writes are checked by immediate readback; settings errors do not turn a failed test into success.

## Update, remove and recover

- Repeating Install is idempotent. For an unchanged v0.2 runner, it also repairs a disabled script or incorrect run context.
- A matching name alone is never ownership. Duplicate names, missing ownership/version attributes, unsupported versions, changed Source, unsaved editor changes, and child content all block running/updating/removing that runner.
- **v0.1 migration:** its untagged runner is deliberately not adopted. In your disposable place, inspect and preserve it yourself, then rename it out of the reserved name or manually remove it only after confirming it contains no work to keep. Install v0.2 afterward.
- Before loading a future plugin build with different runner source, use the **old build's Remove owned test runner** first. Then reload the local plugin and install the new runner. There is no automatic overwrite of unknown or modified runner content.
- **Remove owned test runner** detaches only the exact owned, unmodified runner in edit mode. Undo restores it. Other scripts and player data are not touched by the plugin.
- **Cancel / retry session cleanup** requests cancellation for the plugin's pending session. The plugin watchdog allows the case timeout plus 30 seconds for launch/transport, then up to 5 seconds for cleanup; a completed call may also need up to 5 seconds for edit mode to settle.
- The UI recovers to a failure report, but another native test remains blocked until the outstanding call actually returns **and** edit mode is confirmed. If Studio ignores cancellation, use Studio's Stop button. If the engine remains hung, reopen the disposable place. Closing the panel merely hides it; unloading the plugin requests cancellation.
- Outside Studio, the runner returns before accessing test services. In Studio it also requires server context and valid v0.2 test arguments. Ordinary unmarked playtests receive no scenario execution, player additions, or EndTest calls.
- The installed Script is included if you save/publish the place with it present. Remove it before shipping your game. This task does not publish anything.

## Developer checks

`src/` is authoritative. Never edit generated distribution code.

```bash
python scripts_build.py
python -m unittest discover -s tests -v
```

Python uses only the standard library. For Luau mock execution and syntax compilation, install the official [Luau CLI 0.742](https://github.com/luau-lang/luau/releases/tag/0.742), put the tools on PATH, or set `LUAU_BIN` and `LUAU_COMPILE_BIN`. A local `.tools/luau/` installation is also detected and ignored by Git. Without tools, those tests explicitly report SKIPPED; build/integrity checks still run. CI installs the pinned official Linux release with a SHA-256 check and requires all tests, plus an unchanged rebuilt distribution.

The Luau tests execute the actual protocol, scenario, session, installation and history modules against mocks, including the generated server boundary. **They do not execute Roblox Studio, validate API permissions, or demonstrate real multiplayer success.** See [offline verification](docs/RA-001_VERIFICATION.md), [API audit](docs/API_AUDIT.md), and the exact [Studio validation procedure](docs/STUDIO_VALIDATION.md).

No network requests, telemetry, accounts, AI API, subscriptions, licensing or payment layer are implemented. HttpService is used only for local JSON encoding/decoding and random run identifiers. Reports contain counts and predefined diagnoses, not game source, player names, or user IDs. Only the owned runner source is inspected for integrity.

Custom spawn systems must produce parented characters with Humanoids to pass the current spawn assertion. No client UI, game remotes, purchases, combat, matchmaking, or data-store assertions are implemented. A paid-feature proposal stays behind the human Studio-validation gate defined in RA-001.

## Working instructions and references

Start with [AGENTS.md](AGENTS.md), [CODEX_START_HERE.md](CODEX_START_HERE.md), and [RA-001](docs/CODEX_TASK.md).

- [Official StudioTestService API](https://create.roblox.com/docs/reference/engine/classes/StudioTestService)
- [Official Studio plugin guide](https://create.roblox.com/docs/studio/plugins)
