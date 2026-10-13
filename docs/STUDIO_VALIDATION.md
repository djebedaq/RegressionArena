# Roblox Studio validation — UNVERIFIED

**No Roblox Studio runtime test was run for this change.** A Studio process was detected on the developer machine, but native UI control was unavailable to this agent. Python checks, Luau mock execution, and compilation are not engine validation.

Acceptance A has offline evidence in RA-001_VERIFICATION.md. Acceptance B–G remain **NOT YET VERIFIED**. Every runtime row below is **UNVERIFIED**; do not change it to PASS without actual Output/report evidence.

## Preparation

1. Use a disposable **local copy** of a simple baseplate with normal spawning. Do not use a live production place or production data access. The plugin does not sandbox the game's own scripts.
2. Record the Studio version, OS, player count, case timeouts, plugin revision, and date.
3. Enable Plugin Debugging Enabled. Install the generated distribution as a local plugin using README steps. Delete the temporary ServerStorage installation Script.
4. Open Output and Explorer. Confirm Studio edit mode. Keep one baseline version of the plugin enabled.
5. Collect Results JSON and actual server/client Output for each case. Include screenshots only as supplementary evidence. Do not paste game source or personal data into shared reports.

| ID | Action | Expected | Evidence collected | Result |
| --- | --- | --- | --- | --- |
| ST-01 | Install local plugin; open panel and resize to 300px wide/300px high | Toolbar/widget work; plan and Results accessible by scrolling; copy works | None | UNVERIFIED |
| ST-02 | Install twice; disable owned Script and click Install again | Exactly one tagged v0.2 runner, Enabled=true, Legacy context; no unrelated edits | None | UNVERIFIED |
| ST-03 | Select join only; run separately for 1, 2, 4 players | Correct exact count, matching run identifiers, genuine PASS, automatic return to edit mode | None | UNVERIFIED |
| ST-04 | Select spawn only; run separately for 1, 2, 4 players | Exact player and character/Humanoid counts, genuine PASS | None | UNVERIFIED |
| ST-05 | Select latejoin only; run separately for 1, 2, 4 initial players | Initial count n, final n+1, addedCount=1, retained=true; no client windows left behind | None | UNVERIFIED |
| ST-06 | Disable CharacterAutoLoads as below; spawn only, 2 players, 5s | FAIL, readyCount=0, expected/observed/elapsed and loader diagnosis; never PASS | None | UNVERIFIED |
| ST-07 | Run all three cases twice back-to-back; cancel a third run | Fresh per-case identifiers, no duplicates/stale PASS/hanging sessions, controls recover | None | UNVERIFIED |
| ST-08 | Use ordinary Studio Play, Run and multiplayer test without RA arguments | No RA AddPlayers/EndTest actions and no runner errors/interference | None | UNVERIFIED |
| ST-09 | Remove owned runner; repeat Remove; Undo and Redo once | Only exact RA runner removed/restored; unrelated script content unchanged | None | UNVERIFIED |
| ST-10 | Separately authorized normal published-runtime check with runner present | Runner exits before test-service access, with no RA actions | None | UNVERIFIED |
| ST-11 | Try name collisions, duplicate names, unknown version, modified Source, unsaved editor edits and runner child content | Run/update/remove refuse; every candidate and its contents preserved | None | UNVERIFIED |
| ST-12 | Marked-suite watchdog fault fixture, Cancel, plugin unload/reload | No PASS; cleanup requested, controls recover, unresolved native call prevents overlapping launch | None | UNVERIFIED |
| ST-13 | Malformed/stale result fixture, then restore baseline and rerun | Failure replaces earlier PASS; remaining cases explicitly not run; healthy rerun allowed | None | UNVERIFIED |
| ST-14 | Save/load preset, reload plugin, run 12 short plans, inspect saved history | Plan retained, 10 bounded reports, latest saved report labeled previous; no game assets for settings | None | UNVERIFIED |
| ST-15 | Deny/revoke script access where supported; exercise Undo recording errors and EndTest fault fixture | Installation fails without half-created asset; EndTest error never retries PASS; cleanup diagnosis shown | None | UNVERIFIED |

ST-10 requires an existing, separately approved runtime environment. **Do not publish any place or plugin for this task merely to check this row.** If none is available, leave the row UNVERIFIED.

## Reproducible failing spawn (ST-06)

1. In the disposable place, add a clearly temporary Script named `RA_Validation_NoAutoSpawn` to ServerScriptService:
   ```luau
   game:GetService("Players").CharacterAutoLoads = false
   ```
2. Verify there is no custom loader calling LoadCharacter. Stop any earlier session.
3. In RA, choose 2 players, deselect join/latejoin, set spawn timeout to 5, and run.
4. Expect FAIL with zero ready characters and a CharacterAutoLoads/custom-loader next check. The server watchdog may instead report its deadline if it wins the scheduling race; that must also be FAIL. Save exact Output/JSON and elapsed time.
5. Delete only this temporary validation Script, restore the baseline, then rerun spawn with 20 seconds. Require real success evidence before marking the positive case PASS.

## Collision and removal tests (ST-09/ST-11)

1. With no runner installed, add a customer dummy Script named `RegressionArena_TestRunner`, with a comment and no RA attributes. Click Install and Remove: both must refuse; compare its Source afterward.
2. Preserve/rename the dummy, then install the owned runner. Add a child Folder containing a dummy Script: update/remove must refuse. Remove only the temporary child fixture.
3. Duplicate the owned runner: both install/remove and Run must refuse. Remove the temporary duplicate manually.
4. Change RAVersion to an unknown value, then restore it. Edit Source and also test an unsaved editor change: actions must refuse until the original source is restored.
5. Add an unrelated `CustomerSentinel` Script containing only a recognizable comment. Record its Source/attributes. Remove the owned runner, repeat, Undo/Redo, and compare the sentinel. Delete only temporary fixtures afterward.

## Developer-only fault fixtures (ST-12/ST-13/ST-15)

Use a separate scratch checkout and disposable place; these changes are **not** product features or shipped hooks. Never edit dist by hand.

1. Remove the baseline owned runner using the baseline plugin. Disable that local plugin before saving a fault variant under a separate local filename. This avoids widget conflicts and strict-source collisions.
2. For a real native watchdog test, change only the Session environment's `encode` callback in `src/RegressionArena.plugin.template.luau` to `function() return "RA-INVALID" end`. Rebuild and save/reload the fault local plugin, install its runner, select join with 5 seconds and Run. The runner ignores the invalid marker; the plugin must fail after the 35-second launch/scenario allowance, request cleanup, and reject overlapping runs until the native call completes in edit mode. Use Studio Stop if needed.
3. Cancel a normal marked run during startup. Also disable/reload the plugin during a run. Capture Output and check all server/client windows close; after reload, do not start a new suite until Studio is in edit mode. Record any engine hang as FAIL.
4. For malformed-result handling, restore the normal encode callback and change only the Session environment's `decode` callback to `function() return {passed=true} end`. A finished test must show FAIL, replacing any earlier displayed PASS. Repeat with a decoded valid result whose runId is changed to `"stale"`.
5. To exercise the server EndTest error boundary, in the scratch runner source replace the call inside finish's protected function with `error("RA validation EndTest failure")`. Rebuild; remove the previous owned runner using its matching plugin build before installing the new one. Expect Output warning and cleanup/failure, never a successful report.
6. Restore baseline sources, rebuild, remove each matching fault runner with its matching plugin, disable/delete the local fault plugin copies, re-enable baseline, and reinstall its runner. A healthy rerun must work. If any native call remains outstanding, stop/reopen the disposable place first.

Permission denial and recording behavior depend on current Studio settings. Use real available permission controls; do not claim a simulated Lua exception proves an actual permission denial.

## Preset/history test (ST-14)

1. Select spawn only, 4 players, timeout 15; Save local preset. Change every control, Load, and compare.
2. Enter blank/non-numeric/4/61/5.5 timeouts for an enabled case, or deselect all cases. Run/Save must refuse without starting or altering the current preset.
3. Reload the plugin; Load must restore the saved plan. Show last saved report must never imply it is the current run.
4. Run twelve plans, then reload. In the local debugger, inspect the plugin's `regression-arena-v02-history` setting: at most ten strings, each <=8192 bytes. The preset setting is a bounded plan JSON string. Confirm no preset/history Instances were created.
5. Where possible, test settings failures/conflicting Studio instances. A failed readback must show a storage failure; it must not alter scenario results or leave controls busy.

## Remaining runtime risks

- Server API access, serialization, AddPlayers behavior, edit-mode transitions and LeaveTest effectiveness require actual Studio validation; see API_AUDIT.md.
- A native hang or Studio process crash cannot be guaranteed to clean itself up. The plugin avoids another launch while it still knows a call is outstanding.
- Removal/Undo and pending cleanup across plugin reload need engine evidence. Strict source checks intentionally require manual handling of old or modified runners.
- Game code may access persistent data or external services during a test. Use isolated copies and disable those integrations yourself.
- Counts and server-side characters are smoke assertions; they do not establish client gameplay/UI readiness or compatibility with every custom loader.

Mark each row PASS/FAIL only after observing it. Preserve exact logs, Studio version and revision. No paid-feature implementation or production-readiness claim before this gate passes.
