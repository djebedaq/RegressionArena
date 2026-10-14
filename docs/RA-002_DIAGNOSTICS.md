# RA-002 — multiplayer diagnosis and stability

Date: 2026-10-14. Branch `codex/ra-001-v0.2`; existing Draft PR #1. Starting commit `cb0c5b6a787f462b677c5a970adeccdeb4311f5e`. Studio 0.742.0.7421053, Windows, same unpublished local Baseplate. No production source change has been justified by the evidence collected so far.

**Status: incomplete.** The standard four-client control encountered native/UI responsiveness failures and Computer Use could not recover. The two-client control and three consecutive full two-player RA plans are UNVERIFIED in this RA-002 run. Earlier isolated successes do not satisfy that new stability gate.

## Independent native control

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

## Next controlled steps

1. End the native session using Studio UI; confirm only the original local Baseplate remains. Preserve all evidence and remove only the named observer after the native controls.
2. Repeat Server & Clients with two clients, changing ExpectedClients to 2 on the observer. Record launch-to-join/ready time, Output, resources and actual End Session cleanup. Do not run RA concurrently.
3. Compare with RA using the unchanged audited build and an explicit 180-second budget if justified by native startup timings. Require **three consecutive complete two-player plans**, each join/spawn/latejoin, with fresh evidence and all native windows closed automatically. Preserve failed attempts; never count a manually stopped run as a successful plan.
4. If a native control is reliable but RA differs, isolate the smallest API/lifecycle difference before changing production source, and add a matching regression check plus another Studio run.
5. Continue safe unfinished ST cases after UI recovery. Actual permission denial/revocation remains UNVERIFIED for human testing. Publishing is prohibited; published-runtime testing remains UNVERIFIED.

## Proposed v0.2 support decision

The control follows the [official Studio multi-client testing procedure](https://create.roblox.com/docs/studio/testing-modes). [StudioTestService's documented contexts and limits](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/StudioTestService.yaml) do not provide a plugin-side emergency stop. No unsupported fallback or security-setting change was attempted during this run.

Do not describe four-player mode as verified or supported by this machine's evidence. A safe first-release proposal is to expose only 1/2 initial-player configurations **after the two-player three-plan gate passes**, with the validated timeout/environment documented. Four-player mode should stay behind an explicit experimental boundary or be omitted from the first supported UI. This is a proposal; no configuration was silently removed and the original 1/2/4 acceptance gate has not been waived.

If two-player repeatability also cannot be demonstrated, keep v0.2 a Draft prototype. One-player successes and mocked tests are insufficient to claim reliable two-player support. No paid or marketing features are added.

## Automatic checks actually run

- `python scripts_build.py`: exit 0; generated distribution unchanged, SHA-256 `b720bc1fad06863421b99feaa278039b52ab9a9788ea070e702d95cba64d6b97`.
- `python -m unittest discover -s tests -v`: **19 tests OK, zero skips, 31.983 seconds**; **72 Luau mock cases**, plus nine source/generated compile inputs. These do not execute Roblox Studio.
- `python scripts_studio_validation.py`: exit 0; both ownership renderings, Observer and NativeObserver additionally compiled with official Luau 0.742, all exit 0.
- Exact stdout/stderr and exit codes: [RA-002_TEST_LOG.txt](RA-002_TEST_LOG.txt). GitHub CI is recorded in the Draft PR after pushing this diagnostic record.

Computer Use follows the bundled computer-use SKILL.md and its guidance.md. The exhausted recovery path requires: "then stop and report that the Windows Computer Use helper may have failed." Further native UI tests require the pending human recovery rather than shell-driven UI/process termination. Permission-denial tests remain UNVERIFIED under the separate prohibition on acting on security/privacy permission requests.
