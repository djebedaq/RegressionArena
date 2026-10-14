# Roblox Studio validation — actual execution record

Real tests were run with Computer Use in Roblox Studio **0.742.0.7421053**, Windows, on 2026-10-13. Only a newly created, unpublished local Baseplate under ignored `.tools/studio-validation/` was used. No game or plugin was published. See [raw JSON and screenshots](studio-evidence/README.md). Python checks, Luau mocks and compilation remain separate offline checks.

The complete acceptance gate has **not passed**. One-player suites passed twice in sequence; all three scenarios have positive evidence with two players across separate runs. Four-player attempts failed, including an isolated 180-second join with only two observed clients and native built-in plugin responsiveness failures. Partial rows explicitly identify UNVERIFIED subcases. Successful cases must not erase earlier failures.

RA-002 follow-up on 2026-10-14: the independent native four-client control also encountered severe environment/UI responsiveness failures with no RA runner installed. Computer Use recovery failed; the native two-client control and three consecutive full two-player plans remain UNVERIFIED in that run. See [RA-002 diagnostics and measured resource limits](RA-002_DIAGNOSTICS.md). This does not change the PASS/FAIL attribution of the earlier RA-001 reports.

## Preparation

1. Use a disposable **local copy** of a simple baseplate with normal spawning. Do not use a live production place or production data access. The plugin does not sandbox the game's own scripts.
2. Record the Studio version, OS, player count, case timeouts, plugin revision, and date.
3. Install the generated distribution as a local plugin using README steps. Local installation was observed without changing security settings. Remove only the temporary ServerStorage installation Script.
4. Open Output and Explorer. Confirm Studio edit mode. Keep one baseline version of the plugin enabled.
5. Collect Results JSON and actual server/client Output for each case. Include screenshots only as supplementary evidence. Do not paste game source or personal data into shared reports.

| ID | Action | Expected | Evidence collected | Result |
| --- | --- | --- | --- | --- |
| ST-01 | Install local plugin; open panel and resize to 300px wide/300px high | Toolbar/widget work; plan and Results accessible by scrolling; copy works | Local save/reload, toolbar, scrolling and Ctrl+A/C copy observed. Narrow floating panel exposed clipped buttons; shorter wrapped labels added. Exact 300x300 resize remains UNVERIFIED. | PARTIAL |
| ST-02 | Install twice; disable owned Script and click Install again | Exactly one tagged v0.2 runner, Enabled=true, Legacy context; no unrelated edits | Repeated install, disabled-runner repair and actual Output count=1, true, Legacy, RegressionArena, 0.2.0. Screenshot ST-02; later final-build count also confirmed. | PASS |
| ST-03 | Select join only; run separately for 1, 2, 4 players | Correct exact count, matching run identifiers, genuine PASS, automatic return to edit mode | 1p PASS; 2p PASS including final build at 131.17s; isolated 4p/180s FAIL, observed 2/4 at 180.07s (17:24:04Z report). | FAIL — 4p |
| ST-04 | Select spawn only; run separately for 1, 2, 4 players | Exact player and character/Humanoid counts, genuine PASS | 1p PASS in two suites; 2p final-build PASS with 2/2 ready at 52.83s. 4p attempt hit watchdog; final-build isolated 4p spawn remains UNVERIFIED after native responsiveness failures. | FAIL / UNVERIFIED — 4p |
| ST-05 | Select latejoin only; run separately for 1, 2, 4 initial players | Initial count n, final n+1, addedCount=1, retained=true; no client windows left behind | 1p to 2p PASS twice; isolated final-build 2p to 3p PASS at 92.64s (17:08:30Z). 4p attempt watchdog at 219.94s (17:15:41Z). | FAIL — 4p |
| ST-06 | Disable CharacterAutoLoads as below; spawn only, 2 players, 5s | FAIL, readyCount=0, expected/observed/elapsed and loader diagnosis; never PASS | Real fixture printed CharacterAutoLoads=false. 5s FAIL at 5.0005s; stronger 180s repeat observed 2 players / 0 characters with Humanoids at 180.0117s, with loader diagnosis. Fixture detached afterward. | PASS — expected failure |
| ST-07 | Run all three cases twice back-to-back; cancel a third run | Fresh per-case identifiers, no duplicates/stale PASS/hanging sessions, controls recover | Initial delayed Stop race repaired; intermediate 1p suites 14:26:05Z and 14:28:24Z both 3/3 PASS with distinct IDs and automatic cleanup. Earlier Cancel click had unknown delivery. Current-build repeat at 18:11:57Z confirmed cancellation, 0/3, remaining cases not run; server later ended normally. Healthy current-build recovery at 18:14:45Z passed 3/3; final 18:47:38Z suite also passed 3/3. Higher counts remain unreliable. | PARTIAL; Cancel verified |
| ST-08 | Use ordinary Studio Play, Run and multiplayer test without RA arguments | No RA AddPlayers/EndTest actions and no runner errors/interference | Real Run (18:20:48Z), Play (18:21:55Z) and 1-client Server and Clients (18:23:30Z). Observer confirmed nil args and active server; multiplayer later showed exactly one client and stayed active until UI End Session. No runner errors observed. | PASS — observed sessions |
| ST-09 | Remove owned runner; repeat Remove; Undo and Redo once | Only exact RA runner removed/restored; unrelated script content unchanged | Actual UI Remove/repeat, Ctrl+Z restored matching Source, uninterrupted Ctrl+Z/Ctrl+Y cycle removed it again. Output at 18:09:37Z and 18:11:21Z confirms runner true/source true then runner false; sentinel true both times. Reinstalled baseline afterward. | PASS |
| ST-10 | Separately authorized normal published-runtime check with runner present | Runner exits before test-service access, with no RA actions | None | UNVERIFIED |
| ST-11 | Try name collisions, duplicate names, unknown version, modified Source, unsaved editor edits and runner child content | Run/update/remove refuse; every candidate and its contents preserved | Developer-only local validation plugin ran actual RunnerManager with engine services: 9/9 checks passed, baseline intact, including install/repair, version/Source/children/duplicate/unowned/wrong-class preservation and repeated removal. Unsaved editor divergence and direct Run-button collision subcases remain UNVERIFIED. | PARTIAL — 9 engine checks PASS |
| ST-12 | Marked-suite watchdog fault fixture, Cancel, plugin unload/reload | No PASS; cancellation never claims native termination; unresolved native call prevents overlapping launch | Actual startup/watchdog failures, blocked overlapping Run and live result cancellation observed. Edit-mode local plugin reload observed. Controlled invalid-marker fixture and live unload remain UNVERIFIED. | PARTIAL |
| ST-13 | Malformed/stale result fixture, then restore baseline and rerun | Failure replaces earlier PASS; remaining cases explicitly not run; healthy rerun allowed | Actual malformed fixture at 18:32:37Z became 0/3 FAIL, replacing 3/3 PASS. Replay of the real earlier join PASS with its old nonce at 18:39:38Z was also rejected, 0/3 with remaining cases not run. Fixtures detached; healthy 18:47:38Z rerun passed 3/3 (17.10s / 12.68s / 33.64s). | PASS |
| ST-14 | Save/load preset, reload plugin, run 12 short plans, inspect saved history | Plan retained, 10 bounded reports, latest saved report labeled previous; no game assets for settings | Preset restored across local-plugin reload (1p, all cases, 60s), 127 bytes. Nineteen plans collected; live history retained 10, largest observed 1549 bytes. Show last saved report displayed SAVED REPORT (previous run). Run and Save both refused timeout 181; Load restored 60 without altering the preset. Other invalid inputs and conflicting writes remain UNVERIFIED. | PARTIAL |
| ST-15 | Deny/revoke script access where supported; exercise Undo recording errors and EndTest fault fixture | Installation fails without half-created asset; EndTest error never retries PASS; cleanup diagnosis shown | Command-bar ownership attempt refused TryBeginRecording: 0/9 checks, baseline unchanged, temporary container detached. Same checks subsequently passed from real plugin context. Permission denial/revocation and deliberate EndTest exception remain UNVERIFIED. | PARTIAL — recording refusal observed |

ST-10 requires an existing, separately approved runtime environment. **Do not publish any place or plugin for this task merely to check this row.** If none is available, leave the row UNVERIFIED.

## Reproducible failing spawn (ST-06)

1. In the disposable place, add a clearly temporary Script named `RA_Validation_NoAutoSpawn` to ServerScriptService:
   ```luau
   game:GetService("Players").CharacterAutoLoads = false
   ```
2. Verify there is no custom loader calling LoadCharacter. Stop any earlier session.
3. In RA, choose 2 players, deselect join/latejoin, set spawn timeout to 5, and run.
4. Expect FAIL with zero ready characters and a CharacterAutoLoads/custom-loader next check. The server watchdog may instead report its deadline if it wins the scheduling race; that must also be FAIL. Save exact Output/JSON and elapsed time.
5. Detach only this temporary validation Script, restore the baseline, then rerun spawn with 60 seconds (up to 180 on slower machines). Require real success evidence before marking the positive case PASS.

## Collision and removal tests (ST-09/ST-11)

The executed engine integration entry is generated by `python scripts_studio_validation.py`: install `.tools/studio-validation/ownership-validation.plugin.luau` as a temporary local plugin through Studio, then click **Validate ownership** in the disposable Baseplate with the baseline runner installed. It uses the actual RunnerManager module, Instances, ScriptEditorService and plugin-owned ChangeHistoryService recordings inside a separate named container. The command rendering is diagnostic only: its first attempt refused recording and ran 0/9 checks. Plugin context subsequently passed 9/9. Remove the temporary container after any Undo experiments and disable the validation plugin afterward. Unsaved editor and direct Run-button refusal still require the following UI subcases.

1. With no runner installed, add a customer dummy Script named `RegressionArena_TestRunner`, with a comment and no RA attributes. Click Install and Remove: both must refuse; compare its Source afterward.
2. Preserve/rename the dummy, then install the owned runner. Add a child Folder containing a dummy Script: update/remove must refuse. Remove only the temporary child fixture.
3. Duplicate the owned runner: both install/remove and Run must refuse. Remove the temporary duplicate manually.
4. Change RAVersion to an unknown value, then restore it. Edit Source and also test an unsaved editor change: actions must refuse until the original source is restored.
5. Add an unrelated `CustomerSentinel` Script containing only a recognizable comment. Record its Source/attributes. Remove the owned runner, repeat, Undo/Redo, and compare the sentinel. Delete only temporary fixtures afterward.

## Developer-only fault fixtures (ST-12/ST-13/ST-15)

Use a separate scratch checkout and disposable place; these changes are **not** product features or shipped hooks. Never edit dist by hand.

The actually executed malformed/stale alternative uses `tests/studio/Observer.server.luau` as `RA_Validation_Observer` in the scratch ServerScriptService. Without attributes it only observes unmarked sessions. Set `Fault="malformed"` to end a marked session with `{"passed":true}`. For `Fault="stale"`, set `PreviousResult` to the exact earlier successful join result JSON (same scenario/count/timeout, old nonce); do not invent success evidence. Both were rejected. Detach this fixture before a healthy rerun. The separate invalid-marker, live unload and deliberate EndTest-error variants below remain UNVERIFIED.

1. Remove the baseline owned runner using the baseline plugin. Disable that local plugin before saving a fault variant under a separate local filename. This avoids widget conflicts and strict-source collisions.
2. For a real native watchdog test, change only the Session environment's `encode` callback in `src/RegressionArena.plugin.template.luau` to `function() return "RA-INVALID" end`. Rebuild and save/reload the fault local plugin, install its runner, select join with 5 seconds and Run. The runner ignores the invalid marker; the plugin must fail after the 35-second launch/scenario allowance plus recovery observation, discard late results, and reject overlapping runs until the native call completes in stable edit mode. Use Studio Stop: an unmarked runner must not end the native session.
3. Cancel a normal marked run during startup. Also disable/reload the plugin during a run. Capture Output and check all server/client windows close; after reload, do not start a new suite until Studio is in edit mode. Record any engine hang as FAIL.
4. For malformed-result handling, restore the normal encode callback and change only the Session environment's `decode` callback to `function() return {passed=true} end`. A finished test must show FAIL, replacing any earlier displayed PASS. Repeat with a decoded valid result whose runId is changed to `"stale"`.
5. To exercise the server EndTest error boundary, in the scratch runner source replace the call inside finish's protected function with `error("RA validation EndTest failure")`. Rebuild; remove the previous owned runner using its matching plugin build before installing the new one. Expect Output warning and cleanup/failure, never a successful report.
6. Restore baseline sources, rebuild, remove each matching fault runner with its matching plugin, disable/delete the local fault plugin copies, re-enable baseline, and reinstall its runner. A healthy rerun must work. If any native call remains outstanding, stop/reopen the disposable place first.

Permission denial and recording behavior depend on current Studio settings. Do not claim a simulated Lua exception proves an actual permission denial. Computer Use safety instructions prohibit acting on security/privacy permission requests or changing those settings; those subcases require a human and remain UNVERIFIED.

## Preset/history test (ST-14)

1. Select spawn only, 4 players, timeout 15; Save local preset. Change every control, Load, and compare.
2. Enter blank/non-numeric/4/181/5.5 timeouts for an enabled case, or deselect all cases. Run/Save must refuse without starting or altering the current preset.
3. Reload the plugin; Load must restore the saved plan. Show last saved report must never imply it is the current run.
4. Run twelve plans, then reload. In the local debugger, inspect the plugin's `regression-arena-v02-history` setting: at most ten strings, each <=8192 bytes. The preset setting is a bounded plan JSON string. Confirm no preset/history Instances were created.
5. Where possible, test settings failures/conflicting Studio instances. A failed readback must show a storage failure; it must not alter scenario results or leave controls busy.

## Remaining runtime risks

- Server APIs, JSON transport and AddPlayers have positive engine evidence for 1/2 players. Four-player startup and repeatability still fail on the validation machine; see API_AUDIT.md.
- A native hang or Studio process crash cannot be guaranteed to clean itself up. The plugin avoids another launch while it still knows a call is outstanding.
- Removal/Undo/Redo have engine evidence. Pending cleanup across live plugin reload and unsaved editor divergence still need evidence. Strict source checks intentionally require manual handling of old or modified runners.
- Game code may access persistent data or external services during a test. Use isolated copies and disable those integrations yourself.
- Counts and server-side characters are smoke assertions; they do not establish client gameplay/UI readiness or compatibility with every custom loader.

Mark each row PASS/FAIL only after observing it. Preserve exact logs, Studio version and revision. No paid-feature implementation or production-readiness claim before this gate passes.
