# RA-001 verification record

Runtime date: 2026-10-13; final documentation/restart checks: 2026-10-14. Branch: `codex/ra-001-v0.2`. Base: `main` at `ad5da6b403d9307464f221206cafeb3cdf968f1c`. Draft [PR #1](https://github.com/djebedaq/RegressionArena/pull/1).

## Outcome

Actual Computer Use validation ran in Roblox Studio **0.742.0.7421053** on Windows, using only a new, unpublished local Baseplate in ignored `.tools/studio-validation/`. The plugin was installed with Studio's Save as Local Plugin. No game/plugin publication or PR merge occurred.

**The complete acceptance gate has NOT passed.** One-player suites passed twice consecutively on the intermediate build, and the current build passed a complete 3/3 suite after a real Cancel. All three two-player cases have positive engine evidence across separate runs; full suites still encountered native timeouts. Four-player attempts failed, including only 2/4 clients joined after 180 seconds and a latejoin watchdog. Built-in ExplorerPlugin/Toolbox responsiveness failures were observed under load on this 8 GiB machine. Their root cause is not proven; the plugin must not be called production-ready.

The actual disabled-spawning test correctly failed with **2 players and 0 characters with Humanoids**, including the loader diagnosis. Nine engine ownership checks passed. UI Remove/repeat/Undo/Redo preserved a separate sentinel. Cancel discarded the result and skipped remaining cases while the server ended later; a subsequent normal suite passed. Ordinary Run, Play and Server and Clients remained active with no RA arguments and no runner errors.

Explicit malformed and stale-replay EndTest fixtures both yielded 0/3 FAIL with remaining cases not run. After removing them, the final current-build one-player suite passed 3/3 at 18:47:38Z. Nineteen actual plan reports were preserved, including all observed failures. Invalid timeout 181 was refused by Run and Save without overwriting the valid preset.

Exact [JSON, sanitized engine events and screenshots](studio-evidence/README.md) are separate from [offline command output](RA-001_TEST_LOG.txt). The [ST-01–ST-15 matrix](STUDIO_VALIDATION.md) identifies every remaining UNVERIFIED subcase.

The saved scratch place contains only the baseline runner under ServerScriptService and no installation Script under ServerStorage; temporary fixtures were detached. The ownership validation local plugin was reversibly renamed with `.disabled`. After restarting Studio on 2026-10-14 and opening the exact local file, only the baseline Regression Arena toolbar was present. No native test session remained active.

## Corrections driven by API audit and Studio failures

- Removed plugin/server calls to client-only CanLeaveTest/LeaveTest. Cancel and unload discard acceptance of results; server EndTest/deadline remains responsible for native completion. Failed termination directs the user to Studio Stop. No RunService:Stop fallback persists simulation changes.
- A delayed Stop action from a previous native test killed the next case despite edit mode briefly appearing true. Native ownership now requires Execute completion and three continuous seconds in edit mode. Two consecutive suites and a later Cancel recovery passed; this mitigation is not an engine guarantee.
- Increased the default case budget to 60 seconds, with a bounded 5–180-second range. Failures retain actual elapsed time. Cooperative deadlines can exceed their budgets when Studio stalls.
- An observed argument-handoff timeout left a server unmarked. Nil GetTestArgs is now retried at most three times, one second apart. Errors and non-nil unrelated arguments remain inert; missing arguments never authorize EndTest.
- Shortened and wrapped narrow-panel button labels. Cancellation text states that the server finishes. Exact 300x300 usability remains UNVERIFIED.

## Files and reasons

| Files | Purpose |
| --- | --- |
| `src/Protocol.luau`, `RunnerCore.luau` | Strict versioned requests/results and measured join/spawn/latejoin evidence; bounded configuration and deadlines. |
| `src/Session.luau`, `TestRunner.server.luau` | One pending native call, watchdog/result cancellation, stable edit recovery, protected server boundary and bounded argument handoff. |
| `src/RunnerManager.luau`, `Settings.luau` | Exact ownership/source/editor checks, reversible recordings, bounded local settings and write readback. |
| `src/RegressionArena.plugin.template.luau` | Scrolling plan, preset, Results/copy/history, accurate Cancel and explicit runner installation/removal. |
| `scripts_build.py`, generated `dist/RegressionArena.plugin.luau` | Deterministic UTF-8/LF packaging. Source is authoritative; dist was rebuilt, never manually edited. |
| `tests/test_*.py`, `tests/luau/*` | Packaging/integrity/compile checks and deterministic module/boundary mocks, including cleanup and handoff regressions. |
| `scripts_studio_validation.py`, `tests/studio/*` | Developer-only reproducible engine ownership plugin and observer/fault fixture. Not shipped in the product distribution. |
| `.github/workflows/python-checks.yml`, `.gitattributes`, `.gitignore` | Pinned official Luau CI tools, clean generated-diff gate, stable newlines and excluded local artifacts. |
| `README.md`, `docs/API_AUDIT.md`, `docs/CODEX_TASK.md`, `docs/STUDIO_VALIDATION.md` | Actual API contexts, installation/recovery instructions and candid acceptance status. |
| `docs/RA-001_VERIFICATION.md`, `RA-001_TEST_LOG.txt`, `studio-evidence/*` | Review record, exact offline output and real Studio evidence including failures. |

## Automatic checks actually executed

- `python scripts_build.py`: **exit 0**.
- `python -m unittest discover -s tests -v`: **19 tests, OK, zero skips**, in **23.067s**. Includes **72 Luau mock cases**: server boundary 9, ownership 13, settings 9, protocol 14, scenarios 12, session 15. Also compiles seven source files and two generated contexts (nine inputs).
- Developer ownership renderings and observer fixture additionally compiled with the official Luau compiler; exact outputs are in the log. Compilation is not engine execution.
- `git diff --check`: **exit 0**. All 19 JSON report totals and 45 unique case identifiers were checked, and local documentation links resolved.

Python 3.14.6 and official Luau CLI 0.742 were used. Windows developer-tool ZIP SHA-256: `1114966cd8198f407069f07e8b4e6bacf2ded933e4a57d6ddc75617969278c75`. CI pins Linux ZIP `152058b98c60ff1f5b5ec9bca0b8eb37793cae161dd3a05608cc3d8738ba1a4d`. Developer binaries/local place are ignored.

Current distribution SHA-256: `b720bc1fad06863421b99feaa278039b52ab9a9788ea070e702d95cba64d6b97`. The evidence index distinguishes earlier builds from current-build runs.

## Remaining validation and risks

1. Reproduce all three four-player cases and full two-player suites on a responsive Studio environment, then repeat suites and Cancel. Preserve failures and verify all native windows close. Larger resources may help but are not a proven fix.
2. Complete exact 300x300 layout, unsaved editor divergence/direct Run collision, live plugin unload, deliberately invalid-marker and EndTest-exception fixtures, and conflicting settings writes. These remain UNVERIFIED unless the matrix records actual evidence.
3. Published-runtime inertness remains UNVERIFIED: publishing is explicitly prohibited by this task. Offline guard checks are not a substitute.
4. Actual script-permission denial/revocation remains UNVERIFIED. Computer Use instructions forbid changing security/privacy settings or acting on those permission requests; a human must exercise this subcase. Command-bar recording refusal is recorded separately and is not permission-denial proof.
5. Native hangs or crashes may require Studio Stop/reopening the scratch place. Result cancellation cannot terminate an engine session through a nonexistent plugin API. A first retry after late completion may be refused while the three-second stable edit interval is measured.

The plugin uses no network/data-store/payment APIs, but game scripts still execute. Use isolated local copies. Old, modified or untagged runners require manual preservation/migration. Character checks require parented characters with Humanoids and do not establish client gameplay readiness.

No paid feature is proposed or implemented before the required Studio gate passes.
