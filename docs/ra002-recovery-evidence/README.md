# RA-002 recovery evidence — 2026-10-14

Actual Computer Use execution in Roblox Studio **0.742.0.7421053**, Windows, the same unpublished local `RA-v02-Baseplate.rbxl`. Recovery started from commit `b31031a` on `codex/ra-001-v0.2`. No four-client test was launched in this recovery run. No place/plugin publication, merge, security-setting change or unrelated-project edit occurred.

**The requested three consecutive complete one-player plans were NOT achieved.** There were six healthy full-plan attempts: two consecutive 3/3 successes surrounded by four failures. Separate two-player join and spawn checks passed. These results do not establish reliable automatic suites or readiness for Regression Snapshot.

## Native two-client control

The exact owned runner was validated against Source and GetEditorSource, then reversibly detached. Only [NativeObserver.server.luau](../../tests/studio/NativeObserver.server.luau), configured for two clients, remained in ServerScriptService. It calls no StudioTestService methods, adds no players and never ends a session. Output explicitly confirmed the RA runner was absent.

Standard Server & Clients Start was clicked at **07:50:36.173Z**. The observer started at **07:50:54.303Z**, saw both players and both characters with Humanoids at **07:51:37.438Z**, and reported **43.13 server seconds**. That is approximately **61.27 seconds after the recorded click**. The observer's observation window ended without stopping the test. Normal native End Session was clicked at **07:58:43.007Z**, after collecting joining/spawning evidence. All native windows closed; process count returned to one.

The 48 samples in the native phase span launch and cleanup: minimum available RAM **111 MiB**, maximum system CPU **100%**, maximum four Studio processes, one reported unresponsive process, and **8274 MiB** aggregate Studio private commit. Native joining/spawning passed with substantial resource pressure and UI capture/list timeouts; this is not a clean performance or repeatability pass.

Evidence: [configuration](native-2-config.png), [real client view](native-2-client-view.png), [actual UI actions](ui-actions.json), [selected Output and engine lifecycle events](engine-events.txt).

## Build attribution

All product runner Source remained unchanged. Intermediate plugin builds were saved through Studio's Save as Local Plugin, replacing only the existing local validation plugin. Temporary installation Scripts were detached afterward. Saved local plugin XML Source was compared exactly with the generated distribution.

| Build | Distribution SHA-256 | Scope of runtime evidence |
| --- | --- | --- |
| Starting `b31031a` | `b720bc1fad06863421b99feaa278039b52ab9a9788ea070e702d95cba64d6b97` | Native control; first two full plans |
| 10-second edit guard | `e6c8e4eed427453af77149c592d8a803330c93cbfbb73c39f1edbc3547a1551b` | Next four full plans; two consecutive successes, then recurrence |
| Invalid-transport quarantine | `83e132b748cf1f2d56c8dfad517aa8117fd5fcf9c695f5bb90f3ba753e817a54` | Separate 2p join/spawn; first fault attempts; table quarantine |
| Final, explicit restart message | `b832f68555ae1ac2390e79cdd1de3d1080dce5bcba061ba6d38c05c636da6f06` | Repeated isolated table fault and blocked Run/restart message |

The last build differs from the preceding quarantine build only in the Run refusal message. No complete healthy suite was rerun after that message-only change. Do not relabel intermediate successes as a final-build three-plan gate.

## Interpretation of the raw reports

Every `run-*.json` here is an exact plugin-history string plus a trailing LF. The collector only selected this task's date range and 1/2-player reports. `dateUTC` records plan start, while each case's elapsed field measures its server assertion or plugin failure path; it excludes different amounts of native startup/cleanup. Nonces remain unmodified. Reports were copied before the ten-entry live history rolled them out.

The two consecutive healthy successes started at **09:24:27Z** and **09:30:07Z**. No other RA plan or manual Stop occurred between them. All native windows closed automatically. After the second success, a hidden server process lingered without a window until the first one-process sample at **09:38:10.573Z**. The next plan was deliberately held until that process exited naturally. This slow cleanup is a limitation, not an instant-cleanup claim. The following **09:39:01Z** plan failed with nil transport; the three-plan goal failed.

The early 08:56:41Z plan failed latejoin at 180 seconds with one retained player and no added player. The 09:06:01Z and 09:39:01Z plans encountered unexpected **nil** native transport and orphan windows; Output records the actual type. The 09:16:24Z plan lost test arguments, failed through the watchdog and needed End Session. A read-only server Command Bar check at **09:22:38.208Z** still returned `GetTestArgs() == nil` with one connected player. Extending retries cannot be assumed to recover such a cached/missing handoff safely.

## Controlled transport failures

The first `niltransport` fixture attempt (09:58:29Z) was not isolated: the baseline runner later supplied a genuinely proven join result. Its 1/1 report is preserved, but the intended fault test did **not** pass.

The next fixture disabled only the owned runner clone in the marked test server. Its `EndTest(nil)` did not end that session during the observed interval. The plugin failed at **230.173 seconds** and normal UI End Session was required. This is watchdog evidence, not nil-quarantine evidence, and does not establish undocumented API semantics. The edit runner remained enabled and unchanged.

The isolated `invalidtransport` fixture then supplied a table `{passed=true}` as the sole result producer. Actual Output confirmed native transport type **table**. Both the quarantine build (10:10:06Z, 21.538s) and final build (10:22:36Z, 22.165s) produced **0/1 FAIL**, automatically closed the native windows and refused another Run while apparently idle. The final UI explicitly requested Studio restart. No new `Handling request to start test` event followed the quarantine-check clicks.

Evidence: [first non-isolated attempt](nil-fault-attempt-1-not-isolated.png), [nil watchdog](nil-fault-isolated-watchdog.png), [table failure](table-fault-expected-fail.png), [initial refusal](table-fault-quarantine-refusal.png), [final restart instruction](final-quarantine-restart-message.png), and [developer fixture source](../../tests/studio/Observer.server.luau).

The production fix addresses unsafe ownership release after an ambiguous native return. The ten-second guard is only a mitigation: the interruption recurred even after an 11.360-second gap between engine end/start events. Neither change establishes the native engine's root cause or guarantees child-process exit.

## Other safe checks and final state

- Empty-plan Run and Save both refused without launching. Loading afterward restored the original 1p/all-cases/180s preset: [Run refusal](ST14-empty-plan-refused.png), [Save refusal](ST14-empty-preset-refused.png), [preset preserved](ST14-preset-preserved.png).
- Two resize attempts did not change the observed 181x702 floating panel. Exact 300x300 ST-01 remains **UNVERIFIED**. Scrolling and copying have earlier engine evidence; no new exact-size PASS is inferred.
- A built-in MaterialManager profiling warning appeared before testing: [screenshot](recovered-edit-builtin-error.png). It is not attributed to RA. Two guarded staging-cleanup assertions were also logged; subsequent read-only Output confirmed staging detached, storage empty and baseline intact.
- Human recovery handled AutoRecovery and the off-monitor floating panel. Later capture timeouts recovered with a fresh window selection; one lightweight list timeout reset the JS kernel and a fresh call succeeded. No shell-driven UI automation or process termination was used.
- Final Output at **10:27:50.918Z** confirmed unpublished place 0, edit=true, running=false, ServerScriptService count=1, ServerStorage count=0, runner enabled, Source unchanged, fault detached. The local place was saved at approximately **10:28:24Z**. [Final edit screenshot](final-clean-edit.png).
- Only the main Studio window/process remained. The plugin instance is intentionally quarantined after the controlled transport fault: **restart Studio before another Run**. The saved place contains no observer/fault/installation Script.
- No 3-client or 4-client launch occurred. The conditional 2-to-3 latejoin was skipped because the two-player spawn phase reached **159 MiB** free RAM and **100%** system CPU. Earlier RA-001 2-to-3 evidence remains historical, not a latest-build repeat.
- Permission denial/revocation remains **UNVERIFIED for human testing**. Published runtime, live unload, unsaved-editor divergence and other unperformed subcases retain their explicit status in [STUDIO_VALIDATION.md](../STUDIO_VALIDATION.md).

## Measurements and offline checks

[720 passive resource samples](resources.csv) and the [calculated summary](resource-summary.json) retain actual begin/end UTC timestamps. The bounded sampler was restarted twice; gaps were **08:32:54.371Z–08:51:09.793Z** and **09:39:55.872Z–09:45:40.321Z**. In particular, the last healthy-plan failure transition at 09:40:15Z has engine logs but no simultaneous RAM/CPU sample. Do not interpolate or assign a measured cause to that event.

Win32_OperatingSystem supplies physical memory; Win32_Processor.LoadPercentage supplies system CPU; Get-Process supplies Studio counts, working set, private commit and Responding. Shared pages can inflate summed working set, private commit is not resident RAM, Responding is a point-in-time hint and scheduling/queries change cadence. Phase labels can precede UI clicks and include cleanup. This run does not use the earlier unreliable derived CPU metric. Raw logs, unrelated process details, credentials and account identifiers are excluded.

[Final offline command log](../RA-002_RECOVERY_TEST_LOG.txt): build exit 0; **19 Python tests OK, zero skips, 1.238 seconds**, including **75 Luau mock cases** and nine source/generated compilation inputs; ownership renderings and both developer observers additionally compiled, all exit 0. [Earlier 74-case log](intermediate-checks-74.txt) is preserved separately. These are not Roblox engine tests.

[Nil ownership regression](quarantine-regression.txt) fails against the unmodified `b31031a` module and passes against the current module. [Guard regression](guard-regression.txt) fails when the old three-second interval is injected. GitHub CI for the final commit is linked with its exact outcome in Draft PR #1.

## Raw report index

See the table below for every captured plan. Fault reports must be interpreted as described above, not counted toward healthy repeatability.
