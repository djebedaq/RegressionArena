# RA-002 — multiplayer diagnosis and stability

Date: 2026-10-14. Branch `codex/ra-001-v0.2`; existing Draft PR #1. Initial RA-002 control started at `cb0c5b6a787f462b677c5a970adeccdeb4311f5e`; the recovery below started from `b31031a`. Studio 0.742.0.7421053, Windows, same unpublished local Baseplate. Production changes are limited to native-session ownership/recovery and its UI diagnosis; the installed runner Source is unchanged.

**Status: incomplete; keep Draft.** After the human Studio restart, the native two-client control and separate RA two-player join/spawn checks passed. Two consecutive full one-player plans passed, but the third failed. The latest requested three-consecutive-one-player gate was NOT achieved. The earlier three-two-player-plan request was replaced by that narrower recovery scope, not satisfied. No four-client test was rerun, and conditional two-to-three latejoin was skipped for resource pressure.

## Recovery after the Studio restart

The human cleared AutoRecovery and closed/repositioned the off-monitor floating RA panel. Computer Use regained screenshots and input. Initial Output confirmed place 0, edit=true, running=false and exactly one baseline runner. The native two-client control ran without that runner installed and connected two players/two ready characters in **43.13 server seconds**, approximately **61.27 seconds after Start**. Normal UI End Session closed the control. The phase reached **111 MiB free RAM**, **100% system CPU**, four Studio processes and one unresponsive process. This demonstrates native joining/spawning under pressure, not reliable repeated automation.

Six complete healthy RA plans were attempted with one initial player and 180-second case budgets. The starting build failed latejoin (no new player) and then encountered nil native transport/orphan windows. A ten-second edit-mode guard allowed two consecutive 3/3 successes, but another next session still ended prematurely with nil transport. There was also a lost-argument/watchdog failure. The actual reports and build hashes are indexed in [the recovery evidence](ra002-recovery-evidence/README.md); no failure was removed and no manually stopped session was counted as successful.

The observed premature-end windows occurred after **3.516** and **11.360 seconds** between engine end/start events. Delayed native cleanup is a working explanation, not a proven engine cause. A ten-second guard alone is insufficient. An own-code defect was proven: an unexpected native return could release the plugin lock after apparent edit recovery despite orphan windows. The fix retains an ambiguous-operation lock for that plugin instance, fails closed and explicitly requires ending all tests and restarting Studio. It does not invoke client-only LeaveTest or an unsupported native process/stop API.

Regression checks reproduce the unsafe nil-return release against unmodified `b31031a`; current code passes. Real isolated table-result faults verified 0/1 FAIL, automatic native closure and refusal of a new Run, including the final restart instruction. The fixture disables only the owned runner clone in the marked test server. Its edit-mode baseline remained enabled and unchanged. Earlier nil fixture attempts are retained: one was not isolated and received a genuine runner result; the isolated `EndTest(nil)` did not terminate and hit the watchdog. Neither counts as nil-quarantine runtime proof.

Separate RA two-player checks on the quarantine build passed: **join 25.835 seconds**, **spawn 28.299 seconds**, exactly two players and two ready characters. They were run separately after full native cleanup. The spawn phase reached **159 MiB free RAM and 100% CPU**, so 2-to-3 latejoin was not attempted. No 3-client or 4-client launch occurred in recovery.

The final generated/local plugin hash is `b832f68555ae1ac2390e79cdd1de3d1080dce5bcba061ba6d38c05c636da6f06`. The last change after positive two-player checks only clarifies the blocked Run message; its table-fault path was rerun in Studio. Full healthy final-build repeatability remains unverified. At **10:27:50.918Z**, Output confirmed place 0/edit=true/running=false, one unchanged enabled runner, empty ServerStorage and the fault detached. Only the main Studio process/window remained; the local Baseplate was saved. The plugin instance remains intentionally quarantined after the controlled fault: **restart Studio before another test**.

Empty-plan Run/Save refusal and preset preservation were additionally checked. Exact 300x300 resize did not succeed and remains UNVERIFIED. Permission-denial/revocation tests remain UNVERIFIED for a human. The recovery record contains **720 passive resource samples**, exact sampling gaps and selected Output; raw logs and account/process identities are excluded.

## Earlier independent four-client control (preserved historical record)

The owned RA runner was removed through the plugin's explicit Remove action before the control. Its panel was hidden. The native test was started through Studio's own Server & Clients controls, configured to four clients, at **2026-10-14T04:05:37.202Z**. Regression Arena did not start or end this session.

Only the developer fixture `RA002_NativeObserver` was present under ServerScriptService. [Its source](../tests/studio/NativeObserver.server.luau) uses no StudioTestService methods, does not add players or stop the session, and prints only expected/observed player counts, characters with Humanoids and server elapsed time. Output confirmed that the RA runner was absent.

The observer started at **04:06:09.161Z**, approximately 31.96 seconds after the UI start action. Its first snapshot contained zero players/ready characters. This snapshot alone does not prove that clients never connected later. Complete final connection evidence must be checked before declaring the native control PASS or a joining FAIL.

Passive Windows measurements recorded six Studio processes, consistent with the launching editor, server and four clients. Up to all six processes were reported unresponsive. Across the native phase, available physical memory fell to **60 MiB**, system CPU reached **93%**, and aggregate Studio private committed memory reached **9996 MiB**. The machine reports 8127 MiB visible physical RAM and six logical processors. These observations support investigating environment/startup pressure; they do not establish a root cause, a memory allocation error, or a defect in StudioTestService/Regression Arena.

An attempted server-window activation timed out. Two subsequent lightweight window-list requests also timed out. After a JavaScript kernel reset and reinitialization, a fresh list request timed out and the kernel reset again. No further UI actions were issued in that recovery chain. Human End Session/return to edit mode was requested; native-session cleanup is not claimed while that handoff is pending.

Evidence: [actual UI start action](ra002-evidence/ui-actions.json), [four-client configuration screenshot](ra002-evidence/native-4-config.png), [sanitized Output/lifecycle events](ra002-evidence/engine-events.txt), [resource samples](ra002-evidence/resources.csv).

The recording retained 22 baseline samples and 31 native-phase samples. The last native sample was at 04:14:25.160Z, approximately 527.96 seconds after the start action. The phase label was set immediately before the click, so its first sample precedes the click by approximately 0.68 seconds. [Resource summary](ra002-evidence/resource-summary.json) preserves the calculated ranges; interpretation limits below apply.

## Measurement limits

RAM and CPU were sampled read-only outside the UI; all Studio actions used Computer Use. `Win32_OperatingSystem` supplies visible/free physical memory, `Win32_Processor.LoadPercentage` supplies system CPU, and `Get-Process RobloxStudioBeta` supplies process count, working set, private committed memory, cumulative CPU and Responding. No process IDs, account names, command lines or unrelated process details are retained.

The raw derived StudioCPUPercent column is **unreliable and excluded from CPU conclusions**: it divides CPU deltas by timestamps taken before variable-duration system queries, and one value exceeds 100% (104.4). It also excludes newly appearing processes until their second observation. Raw values are preserved instead of silently clamped. The reported CPU maximum above uses the independent Win32_Processor system LoadPercentage readings.

Working-set totals can count shared pages repeatedly; private committed memory is not resident RAM. Sampling was nominally every five seconds, with actual timestamp gaps enlarged by Windows queries/scheduling under load. Decimal values in CSV use the host locale. Missing readings must not be treated as zero.

The formatted performance-counter WMI classes were unavailable (`Invalid class`), so that first attempted method was discarded. Neither its null CPU nor its empty process result is included as valid evidence. The supported read-only measurements above were used instead. Raw Studio logs are not committed.

## Remaining controlled steps

1. Restart Studio before more RA execution after the intentional transport quarantine. Open only the saved disposable local Baseplate and confirm no old native sessions/processes remain. Do not rerun four clients on this machine.
2. On an environment with sufficient resource headroom, require **three consecutive complete plans with one initial player**, including latejoin to two, with fresh nonces and automatic native cleanup. The latest run achieved only two; preserve the remaining failures when comparing results.
3. Retain the separate positive two-player join/spawn evidence. Revalidate the whole final build on a stable machine before describing it as supported. Attempt 2-to-3 latejoin only with resource headroom; it remains UNVERIFIED in recovery.
4. Investigate premature native end/lost arguments with Roblox engine diagnostics; do not assume increasing a fixed delay proves cleanup. No plugin API exposes a complete native child-process exit barrier in the audited interface.
5. Continue safe unfinished ST subcases in the disposable place. Permission denial/revocation requires a human; published-runtime checks remain UNVERIFIED because publication is prohibited. Snapshot implementation has not started.

## Proposed v0.2 support decision

The control follows the [official Studio multi-client testing procedure](https://create.roblox.com/docs/studio/testing-modes). [StudioTestService's documented contexts and limits](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/StudioTestService.yaml) do not provide a plugin-side emergency stop. No unsupported fallback or security-setting change was attempted during this run.

Do not describe four-player mode as verified or supported by this machine's evidence. A safe first-release proposal is a **maximum of two simultaneous clients**, only after the remaining repeatability gate passes: one-initial-player plans may include latejoin to two; two-initial-player checks would include join/spawn, with latejoin to three excluded until separately validated. Four-player mode should be omitted from the first supported UI or clearly experimental. This is a proposal; no configuration was silently removed and the original 1/2/4 acceptance gate has not been waived.

Keep v0.2 a Draft prototype while the latest one-player repeatability gate fails. Separate positive two-player cases and mocked tests are insufficient to claim reliable automatic suites. This run does not justify a ready-for-Snapshot or production-ready claim. No paid or marketing features are added.

## Automatic checks actually run

Final recovery build: `python scripts_build.py` exit 0; `python -m unittest discover -s tests -v`: **19 tests OK, zero skips, 1.238 seconds**, including **75 Luau mock cases** and nine source/generated compile inputs. Developer ownership renderings and both observers also compiled, all exit 0. [Exact final log](RA-002_RECOVERY_TEST_LOG.txt). Distribution SHA-256: `b832f68555ae1ac2390e79cdd1de3d1080dce5bcba061ba6d38c05c636da6f06`. Final-commit GitHub CI outcomes and links are recorded in Draft PR #1.

Initial RA-002 run, before recovery (historical):

- `python scripts_build.py`: exit 0; generated distribution unchanged, SHA-256 `b720bc1fad06863421b99feaa278039b52ab9a9788ea070e702d95cba64d6b97`.
- `python -m unittest discover -s tests -v`: **19 tests OK, zero skips, 31.983 seconds**; **72 Luau mock cases**, plus nine source/generated compile inputs. These do not execute Roblox Studio.
- `python scripts_studio_validation.py`: exit 0; both ownership renderings, Observer and NativeObserver additionally compiled with official Luau 0.742, all exit 0.
- Exact stdout/stderr and exit codes: [RA-002_TEST_LOG.txt](RA-002_TEST_LOG.txt). GitHub CI is recorded in the Draft PR after pushing this diagnostic record.

Computer Use follows the bundled computer-use SKILL.md and guidance.md. The earlier exhausted path required: "then stop and report that the Windows Computer Use helper may have failed." Human recovery subsequently restored access. Later capture/list timeouts recovered through the bounded retry/reset path, with no shell-driven UI or process termination. Permission-denial tests remain UNVERIFIED under the separate rule: "Do not act on security or privacy permission requests."
