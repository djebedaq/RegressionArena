# Regression Arena — v0.2 prototype

**Status: RA-001 implementation with real Roblox Studio evidence. Validation is incomplete; see the recorded PASS/FAIL/UNVERIFIED matrix. Not production-ready or approved for sale.**

[RA-002 diagnostics](docs/RA-002_DIAGNOSTICS.md) record the native-control and repeatability investigation in the same Draft PR. After a Studio restart, the native two-client control and separate RA two-player join/spawn checks passed. Two consecutive complete one-player plans passed, but the third failed; the requested three-plan gate is NOT achieved. Four-player mode and two-to-three latejoin are unverified on the latest recovery run. See the [recovery evidence](docs/ra002-recovery-evidence/README.md), including every failure.

Regression Arena runs repeatable multiplayer smoke checks in a local Roblox Studio place copy. Select `join`, `spawn`, and `latejoin` independently, choose 1/2/4 initial players, and give each case a whole-number timeout of 5–180 seconds (default 60). Each case starts its own multiplayer session. Latejoin requests one additional player after the initial group joins. Slower machines can need a larger budget for local client startup.

A PASS requires a matching run identifier, strict result schema, and scenario evidence. Reports include expected/observed behavior, elapsed seconds, counts, and a suggested next check. A timed-out, cancelled, malformed, or stale result cannot become PASS. Infrastructure failure aborts the remaining cases with explicit “not run” failures.

## Install and run locally

1. Open a **disposable, local copy** of a simple place. Game scripts still execute during tests; keep production credentials, live data access, purchases, and external integrations out of this copy. Regression Arena does not intercept game code or sandbox its side effects.
2. Insert a temporary `Script` named `RegressionArena` under `ServerStorage`; paste `dist/RegressionArena.plugin.luau` into its Source. Local installation was verified in Studio 0.742 without changing security settings.
3. Select it and use **Plugins → Save as Local Plugin**. Delete the temporary Script. Open Regression Arena using its toolbar button.
4. In edit mode, click **Install / repair runner**. The sole place asset created is `ServerScriptService.RegressionArena_TestRunner`, with `RAOwner=RegressionArena`, `RAVersion=0.2.0`, and server Legacy run context. Installation/removal use undo recordings.
5. Select the player count, toggle cases, and enter the timeout under each case. Click **Run selected test plan**. The vertically scrolling panel remains usable in a small dock.
6. Inspect the counts and diagnosis. Click Results and use Ctrl+A / Ctrl+C to copy text and JSON. **Show last saved report** is explicitly labeled as a previous run.
7. **Save local preset** / **Load local preset** retain one plan in plugin settings, without adding game assets. History retains at most ten reports, each at most 8 KiB. The preset is at most 2 KiB when loaded. Writes are checked by immediate readback; settings errors do not turn a failed test into success.

## Update, remove and recover

- Repeating Install is idempotent. For an unchanged v0.2 runner, it also repairs a disabled script or incorrect run context.
- A matching name alone is never ownership. Duplicate names, missing ownership/version attributes, unsupported versions, changed Source, unsaved editor changes, and child content all block running/updating/removing that runner.
- **v0.1 migration:** its untagged runner is deliberately not adopted. In your disposable place, inspect and preserve it yourself, then rename it out of the reserved name or manually remove it only after confirming it contains no work to keep. Install v0.2 afterward.
- Before loading a future plugin build with different runner source, use the **old build's Remove owned runner** first. Then reload the local plugin and install the new runner. There is no automatic overwrite of unknown or modified runner content.
- **Remove owned runner** detaches only the exact owned, unmodified runner in edit mode. Undo restores it. Other scripts and player data are not touched by the plugin.
- **Cancel results (server finishes)** discards the pending result and skips remaining cases. The server still ends through EndTest or its scenario deadline. For immediate termination, use Studio **Stop / End Session**. Roblox's LeaveTest methods are client-only and cannot stop the whole session from a plugin.
- The plugin watchdog allows the case timeout plus 30 seconds for launch/transport. Recovery allows 10 seconds for the edit transition plus a full 10-second settling interval. Native ownership is released only after Execute returns and edit mode stays true for 10 continuous seconds. RA-002 reproduced an interrupted next session with the previous 3-second guard; the longer interval mitigates that observed race but cannot prove every native child process has exited. These are cooperative Lua deadlines; engine stalls can exceed them, and actual elapsed time is preserved.
- Another native test remains blocked while its previous call is outstanding. Missing arguments or a failed EndTest can require Studio Stop; reopen the disposable place if Studio remains hung. Closing the panel merely hides it; unloading discards pending results and does not pretend to terminate the engine session.
- An unexpected native transport (including nil, a table or an oversized string) leaves native cleanup unconfirmed. Run stays blocked for that plugin instance even if the editor looks idle. End all test windows and **restart Studio before retrying**. A longer edit-mode settling interval alone did not prevent this engine/lifecycle failure in RA-002. A real table-result fault verified the conservative lock and its restart instruction.
- Outside Studio, the runner returns before accessing test services. In Studio it also requires server context and valid v0.2 test arguments. Ordinary unmarked playtests receive no scenario execution, player additions, or EndTest calls.
- The installed Script is included if you save/publish the place with it present. Remove it before shipping your game. This task does not publish anything.

## Developer checks

`src/` is authoritative. Never edit generated distribution code.

```bash
python scripts_build.py
python -m unittest discover -s tests -v
```

Python uses only the standard library. For Luau mock execution and syntax compilation, install the official [Luau CLI 0.742](https://github.com/luau-lang/luau/releases/tag/0.742), put the tools on PATH, or set `LUAU_BIN` and `LUAU_COMPILE_BIN`. A local `.tools/luau/` installation is also detected and ignored by Git. Without tools, those tests explicitly report SKIPPED; build/integrity checks still run. CI installs the pinned official Linux release with a SHA-256 check and requires all tests, plus an unchanged rebuilt distribution.

The Luau tests execute the actual protocol, scenario, session, installation and history modules against mocks, including the generated server boundary. **They do not execute Roblox Studio, validate API permissions, or demonstrate real multiplayer success.** See the [verification record](docs/RA-001_VERIFICATION.md), [actual Studio evidence](docs/studio-evidence/README.md), [API audit](docs/API_AUDIT.md), and exact [Studio validation procedure](docs/STUDIO_VALIDATION.md).

No network requests, telemetry, accounts, AI API, subscriptions, licensing or payment layer are implemented. HttpService is used only for local JSON encoding/decoding and random run identifiers. Reports contain counts and predefined diagnoses, not game source, player names, or user IDs. Only the owned runner source is inspected for integrity.

Custom spawn systems must produce parented characters with Humanoids to pass the current spawn assertion. No client UI, game remotes, purchases, combat, matchmaking, or data-store assertions are implemented. A paid-feature proposal stays behind the human Studio-validation gate defined in RA-001.

## Working instructions and references

Start with [AGENTS.md](AGENTS.md), [CODEX_START_HERE.md](CODEX_START_HERE.md), and [RA-001](docs/CODEX_TASK.md).

- [Official StudioTestService API](https://create.roblox.com/docs/reference/engine/classes/StudioTestService)
- [Official Studio plugin guide](https://create.roblox.com/docs/studio/plugins)
