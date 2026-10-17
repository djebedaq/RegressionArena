# RA-001 API and context audit

Reviewed against official Roblox documentation on 2026-10-13 and rechecked on 2026-10-14. The initial reference-page audit missed execution-context details. The subsequent Computer Use validation uses the [official generated class documentation](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/StudioTestService.yaml), which explicitly states the restrictions below. Runtime evidence is recorded separately.

| API | Documented contract / source use |
| --- | --- |
| `ExecuteMultiplayerTestAsync(numPlayers, args): Variant` | Yielding, Plugin Security. Called only by the plugin, with a bounded initial count and JSON string arguments. |
| `GetTestArgs(): Variant` | Server runner accepts only bounded JSON with the current marker, schema, nonce and plan. Nil receives at most three protected reads, one second apart; errors and unrelated non-nil arguments return immediately. No unmarked session is ended. |
| `EndTest(value): ()` | Official example supplies server results. Its return is not a success flag: the value sent is checked by the plugin after Execute returns. |
| `AddPlayers(numPlayers): ()` | Runner requests one; success is measured by retained initial identities, exactly one new identity and the resulting count. |
| `CanLeaveTest(): boolean`, `LeaveTest(): ()` | **Client DataModel only.** These disconnect one client, not the entire session. All plugin/server calls have been removed. |
| `EditModeActive: boolean` | Plugin Security. Checked alongside RunService running state before starting or mutating assets and before releasing native ownership. |

Source: [StudioTestService reference](https://create.roblox.com/docs/reference/engine/classes/StudioTestService).

Other API checks:

- [Studio plugins guide](https://create.roblox.com/docs/studio/plugins): local plugin installation, toolbar actions, Source assignment on new Scripts, and recording edits with TryBeginRecording/FinishRecording.
- [Plugin reference](https://create.roblox.com/docs/reference/engine/classes/Plugin): current CreateDockWidgetPluginGuiAsync, local GetSetting/SetSetting, Unloading. Settings writes are checked by readback; unload discards pending results while the server remains responsible for EndTest.
- [ScriptEditorService reference](https://create.roblox.com/docs/reference/engine/classes/ScriptEditorService): GetEditorSource is Plugin Security. The ownership check reads only the named candidate runner and rejects differing editor text.
- [BaseScript reference](https://create.roblox.com/docs/reference/engine/classes/BaseScript): Enabled and RunContext exist. New runner uses Legacy context under ServerScriptService.
- [ChangeHistoryService reference](https://create.roblox.com/docs/reference/engine/classes/ChangeHistoryService): plugin-only recordings, explicit commit/cancel. Insertion is staged off-tree; failures attempt rollback and recording closure.
- [RunService reference](https://create.roblox.com/docs/reference/engine/classes/RunService): runner checks IsStudio and IsServer before test-service access; plugin checks IsRunning before asset edits.

## Runtime findings and remaining assumptions

RA-002's earlier independent four-client control encountered native/UI responsiveness failures. After the human Studio restart, the independent two-client control connected both players with ready characters in 43.13 server seconds (approximately 61.27 seconds after the recorded Start click), with no RA runner installed. The phase reached 111 MiB available RAM and 100% system CPU. Separate RA two-player join/spawn checks passed. Sequential RA sessions still intermittently ended prematurely with nil transport or lost arguments. [Diagnostics](RA-002_DIAGNOSTICS.md) and [recovery evidence](ra002-recovery-evidence/README.md) distinguish these observations from the working delayed-cleanup explanation. Four clients were not rerun; the root cause is not established.

1. Server GetTestArgs, EndTest and AddPlayers were exercised successfully in Studio 0.742.0.7421053, including a real latejoin from 1 to 2 players. The full 1/2/4 matrix remains subject to the validation record.
2. A loaded server recorded `Arg not received due to timeout` during one launch; the runner then stayed inert and the plugin failed through its watchdog. Nil arguments now receive at most three reads, one second apart; errors and non-nil unrelated markers exit immediately. Even after retries, missing arguments must never authorize EndTest on an unmarked session.
3. Matching JSON requests/results were transported in actual successful runs. An explicit malformed payload and a replay of an actual old valid join PASS with the previous nonce were both rejected by the current plugin, yielding 0/3 FAIL and remaining cases not run (ST-13).
4. Execute can return and expose edit mode before a delayed previous Stop action arrives. The first back-to-back run returned an unexpected next result and left native windows. A 3-second guard allowed two earlier one-player suites, but RA-002 reproduced the interruption: the next test started 3.516 seconds after the preceding `Handling test has ended`, then ended after 1.010 seconds with nil transport and orphan native windows. The guard is now 10 continuous edit seconds, budgeted separately from the 10-second transition allowance. It allowed two consecutive full plans, but another next session still ended prematurely after an 11.360-second gap. Delayed cleanup remains a working explanation, not an established engine root cause. The guard is a mitigation, not a reliable cleanup guarantee. Two mock regressions cover a delayed edit transition and cleanup after the old guard.
5. There is no documented plugin-side StudioTestService session-stop method. Cancel discards results and stops the remaining plan, while the server ends through EndTest/deadline. Native ownership remains locked until Execute returns and edit mode is confirmed. Missing/failed server termination requires the actual Studio Stop button.
6. Reload from a local-plugin save was observed in edit mode. Unloading during a live test and crash/hang recovery still need separate evidence. It cancels acceptance of results, not the native server.
7. Nine RunnerManager checks passed using real Source/GetEditorSource, Instances and plugin-owned recordings. Actual UI Undo restored matching Source and Redo detached only the runner; a sentinel remained intact. The first command-bar attempt refused a recording (0/9, baseline unchanged), so the integration checks were correctly rerun as a local plugin. Unsaved editor divergence and actual permission denial/revocation remain UNVERIFIED. Preset readback/reload and ten-entry history bounds were observed.
8. Latejoin succeeded from 1 to 2 and from 2 to 3 players. Native startup was slow and sometimes unresponsive at higher counts on this 8 GiB machine. A four-player join at 180 seconds observed only two players, and a four-player latejoin hit the plugin watchdog. The default is now 60 seconds and the configurable upper bound is 180; all attempted failures are retained.
9. A real Cancel at startup discarded the join result and marked the remaining cases not run. The server ended later; a new launch was initially refused while stable edit recovery was checked. The subsequent current-build one-player suite passed 3/3. Cancel does not claim immediate native termination.
10. RA-002 exposed a plugin defect: invalid native transport cleared ownership after apparent edit recovery, despite orphan server/client windows. Such a result now quarantines the operation for the plugin instance and requires Studio restart. A nil-return regression fails against the unmodified `b31031a` Session and passes against the new module. Real table transport faults produced 0/1 FAIL, automatic native closure and refusal of another Run, including the final restart message. Strict malformed/stale JSON handling remains separate.
11. A developer `EndTest(nil)` injection did not terminate the isolated server in this run; the watchdog failed at 230.173 seconds and Studio End Session was needed. An earlier, unisolated attempt received the baseline runner's later genuine join result instead. Neither attempt proves nil-transport quarantine. The isolated table fault disables only the owned runner clone in the marked test server to ensure one result producer; the edit runner remains enabled and unchanged. Product EndTest always receives a JSON string. Do not infer undocumented nil behavior from the Variant signature.

## v0.1 findings repaired

| Finding | v0.2 behavior / regression evidence |
| --- | --- |
| Name-only installation could overwrite a customer's script | Exact ownership/version/source/editor checks; collision and rollback mock cases; ST-02/ST-11/ST-15. |
| AddPlayers return assumed sufficient; count could hide replacements | Measure retained initial players and exactly one new identity; RunnerCore mock replacement case; ST-05. |
| Loose result fields and no per-run identity | Strict versioned contract, nonce/config match, finite timings, scenario evidence; Protocol mock cases; ST-13. |
| Vacuous spawn success possible after disconnect | Require the expected nonzero count and ready count together; RunnerCore disconnect case; ST-04/ST-06. |
| API/serialization errors could leave UI busy | Protected boundaries, failure evidence, always release suite controls; Session/runner mocks; ST-07/ST-12/ST-13. |
| No plugin watchdog, cancellation or pending-call lock | Bounded deadlines, result cancellation, late-response rejection and no overlap; Session mocks; ST-07/ST-12. |
| Timeout budgets differed across phases | One server deadline per selected case; shared-budget and exact-deadline mocks; ST-06/ST-12. |
| Unbounded stored input and assumed settings success | Ten reports of at most 8 KiB, whitelisted restoration, one bounded preset, readback checks; Settings mocks; ST-14. |
| Platform-default build encoding and weak marker checks | UTF-8/LF, exact marker counts and delimiter checks, deterministic packaging tests, pinned Luau CI. |

## Cleanup correction during Computer Use validation

The previous implementation incorrectly invoked client-only leave methods from plugin and server code. Those calls and their misleading mock expectations were removed. Cancel/unload discard results without pretending to stop native execution. An EndTest failure warns that Studio Stop is required; it does not retry PASS. A structural regression check forbids those calls in production source.

`RunService:Stop()` is deliberately not a fallback: [its official reference](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/RunService.yaml) says simulation changes persist, unlike Studio's Stop button. This would violate the place-restoration requirement.

## Regression Snapshot / commercial package audit — 2026-10-17

Official references were rechecked for the commercial work: StudioTestService
(plugin launch, server AddPlayers/EndTest; LeaveTest remains client-only),
[Instance](https://create.roblox.com/docs/reference/engine/classes/Instance),
[Selection](https://create.roblox.com/docs/reference/engine/classes/Selection),
[Plugin](https://create.roblox.com/docs/reference/engine/classes/Plugin) and
[plugin guidance](https://create.roblox.com/docs/studio/plugins).

Snapshot runs in the explicitly marked Studio server, after one ready character,
then reads allowed properties/GetAttribute through exact, unique GetChildren paths.
There is no dynamic Source assertion or arbitrary execution. The plugin recomputes
verdicts from bounded evidence, matches the nonce/plan and only captures fresh
successful evidence. Snapshot and Smoke share Session ownership/quarantine.

JSON export uses a selectable read-only TextBox and the user's Ctrl+C/local text
editor flow. No undocumented clipboard/file-write API is assumed.
PromptSaveSelectionAsync saves Instances and was not repurposed for arbitrary JSON.
HttpService is only used for JSON/GUID operations, never HTTP requests.

The deterministic rbxmx asset contains one readable Script and its embedded owned
runner/modules. The distribution ZIP has a strict allowlist, script-free demo and
hash manifest. See release/COMPLIANCE.md for the Creator Store policy review, and
docs/commercial-v1-evidence for actual runtime observations by build hash. Store
moderation, account approval and published-game execution are not inferred from a
source audit or mock tests.
