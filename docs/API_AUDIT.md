# RA-001 API and context audit

Reviewed against official Roblox documentation on 2026-10-13. This is a source audit, not proof of current Studio behavior. Runtime cases are all UNVERIFIED.

| API | Documented contract / source use |
| --- | --- |
| `ExecuteMultiplayerTestAsync(numPlayers, args): Variant` | Yielding, Plugin Security. Called only by the plugin, with a bounded initial count and JSON string arguments. |
| `GetTestArgs(): Variant` | Runner uses a protected read and accepts only a bounded JSON string with the current marker, schema, nonce and plan. Missing/unrelated arguments cause immediate return. |
| `EndTest(value): ()` | Official example supplies server results. Its return is not a success flag: the value sent is checked by the plugin after Execute returns. |
| `AddPlayers(numPlayers): ()` | Runner requests one; success is measured by retained initial identities, exactly one new identity and the resulting count. |
| `CanLeaveTest(): boolean`, `LeaveTest(): ()` | Protected cleanup requests. CanLeave must permit leaving; an attempted Leave does not prove native completion. |
| `EditModeActive: boolean` | Plugin Security. Checked alongside RunService running state before starting or mutating assets and before releasing native ownership. |

Source: [StudioTestService reference](https://create.roblox.com/docs/reference/engine/classes/StudioTestService).

Other API checks:

- [Studio plugins guide](https://create.roblox.com/docs/studio/plugins): local plugin installation, toolbar actions, Source assignment on new Scripts, and recording edits with TryBeginRecording/FinishRecording.
- [Plugin reference](https://create.roblox.com/docs/reference/engine/classes/Plugin): current CreateDockWidgetPluginGuiAsync, local GetSetting/SetSetting, Unloading. Settings writes are checked by readback; unload requests pending-session cleanup.
- [ScriptEditorService reference](https://create.roblox.com/docs/reference/engine/classes/ScriptEditorService): GetEditorSource is Plugin Security. The ownership check reads only the named candidate runner and rejects differing editor text.
- [BaseScript reference](https://create.roblox.com/docs/reference/engine/classes/BaseScript): Enabled and RunContext exist. New runner uses Legacy context under ServerScriptService.
- [ChangeHistoryService reference](https://create.roblox.com/docs/reference/engine/classes/ChangeHistoryService): plugin-only recordings, explicit commit/cancel. Insertion is staged off-tree; failures attempt rollback and recording closure.
- [RunService reference](https://create.roblox.com/docs/reference/engine/classes/RunService): runner checks IsStudio and IsServer before test-service access; plugin checks IsRunning before asset edits.

## Assumptions still requiring Studio evidence

1. The installed server Script can use GetTestArgs, EndTest, and AddPlayers in actual multiplayer tests. The reference gives signatures/examples but does not establish every execution-context detail.
2. GetTestArgs is available when the marked server runner starts. There is no documented need for the v0.1 speculative nil polling. A missing argument now fails through the plugin watchdog.
3. JSON strings preserve the request and response across the plugin/server boundary; Execute returns the EndTest value directly in the deployed Studio build.
4. EditModeActive and IsRunning describe the launching plugin's model as expected, including transitions between cases.
5. CanLeaveTest/LeaveTest are effective from the launching plugin while Execute yields, and server fallback can end an EndTest failure. Cancellation may not complete a native call; pending ownership deliberately blocks further tests.
6. Unloading runs during disable/reload/close and allows cleanup requests to execute. No guarantee is made for a Studio process crash or engine hang.
7. Source access, GetEditorSource on open and closed Scripts, undo recordings, and readback of plugin settings behave correctly with the user's permissions.
8. One late player can be added after the initial 1/2/4 clients. Native window lifecycle, client startup speed, and the default timeout need hardware testing.

## v0.1 findings repaired

| Finding | v0.2 behavior / regression evidence |
| --- | --- |
| Name-only installation could overwrite a customer's script | Exact ownership/version/source/editor checks; collision and rollback mock cases; ST-02/ST-11/ST-15. |
| AddPlayers return assumed sufficient; count could hide replacements | Measure retained initial players and exactly one new identity; RunnerCore mock replacement case; ST-05. |
| Loose result fields and no per-run identity | Strict versioned contract, nonce/config match, finite timings, scenario evidence; Protocol mock cases; ST-13. |
| Vacuous spawn success possible after disconnect | Require the expected nonzero count and ready count together; RunnerCore disconnect case; ST-04/ST-06. |
| API/serialization errors could leave UI busy | Protected boundaries, failure evidence, always release suite controls; Session/runner mocks; ST-07/ST-12/ST-13. |
| No plugin watchdog, cancellation, unload cleanup or pending-call lock | Bounded deadlines, cleanup request, late-response rejection and no overlap; Session mocks; ST-07/ST-12. |
| Timeout budgets differed across phases | One server deadline per selected case; shared-budget and exact-deadline mocks; ST-06/ST-12. |
| Unbounded stored input and assumed settings success | Ten reports of at most 8 KiB, whitelisted restoration, one bounded preset, readback checks; Settings mocks; ST-14. |
| Platform-default build encoding and weak marker checks | UTF-8/LF, exact marker counts and delimiter checks, deterministic packaging tests, pinned Luau CI. |
