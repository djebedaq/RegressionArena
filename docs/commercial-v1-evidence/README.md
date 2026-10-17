# Regression Arena 1.0 Studio evidence

Real Computer Use in Roblox Studio **0.743.0.7431133**, Windows, 8,127 MiB visible
RAM, 2026-10-17–18. JSON files are preserved from the plugin's actual local settings;
screenshots are actual Studio captures. Mocks are recorded separately and do not
establish these runtime outcomes. Times in JSON/resources are UTC; Studio Output
screenshots display Europe/Sofia local time.

## Build identity

- Initial production candidate source SHA-256:
  `3b9fa3321ee74fc103f9039be2a9edfa40d35ae32bbc5f094962e861ec66106b`.
- Updated candidate, installed through **Save as Local Plugin** and byte-compared
  with generated source:
  `dbd8c666496cc9c848db6bf8794eaff5b5998056077a75faf5716693050c4316`.
  Changes add larger bounded serialization envelopes, improve responsive layout,
  tab highlighting, field alignment and runner error presentation. No report from
  the earlier candidate is silently attributed to the updated one.
- Phase 1 safety/recovery evidence belongs to separate hashes under
  [commercial-phase1-evidence](../commercial-phase1-evidence/).

## Initial candidate: clean Baseplate and Snapshot

The standalone `dist/RegressionArena.rbxmx` was opened in Studio, its sole Script
selected and saved as the backed-up local validation plugin. Installed source
matched the generated source. A newly created Baseplate reported PlaceId 0, edit
mode, ServerScriptService 0 and ServerStorage 0 before explicit Setup installation.

| Evidence | Actual outcome |
| --- | --- |
| `smoke-20261017T153545Z-931211e6.json` | Full join/spawn/latejoin plan PASS 3/3; 12.108/10.861/26.891 seconds; latejoin 1→2 with initial retained and one new identity. |
| `snapshot-report-3c365e02.json` | Demo checks PASS 5/5, elapsed 13.331 seconds. |
| `snapshot-baseline-3c365e02.json` | Successful baseline captured through UI and read back locally; Reward 10. |
| `snapshot-report-9be98f5a.json` | Deliberate CanCollide false, Unlocked false and Mode Closed detected as FAIL; object presence PASS and Reward 12 in [5,15] PASS. |
| `snapshot-report-17efc6c1.json` | Restored booleans/string PASS 5/5 against the original baseline; Reward 12 remains valid rather than requiring exact equality to 10. |

Attempting to capture a failed run was refused; the successful baseline remained
unchanged. Demo definitions were loaded and saved through the product UI. The
authoring helper initially included a camera operation which Studio warned might
not be undoable; the warning was **cancelled**, that camera operation removed, and
the helper rerun. No security permission was granted. The shipped demo contains
only geometry/data and no helper scripts.

## Initial candidate: ownership and removal

Real Setup actions plus read-only Command Bar assertions verified:

- Repeated Install kept the same runner and did not create duplicates.
- Remove detached only that runner, preserving a separately created sentinel and
  all demo values. Undo restored the **same** runner instance and exact Source.
- A deliberately edited runner was refused by both Install and Remove, with its
  edited Source preserved. Only the exact deliberate comment was then restored.
- A foreign Folder with the reserved runner name was refused by both actions;
  identity, class and sentinel Attribute remained intact.
- Only the test-owned sentinel was detached. The final distribution demo reported
  zero LuaSourceContainers, ServerScriptService 0 and ServerStorage 0 before Save As.

Corresponding `ownership-*`, `edited-*`, `foreign-*` and clean-demo screenshots
record the UI and Output. The pre-existing recovery place was never overwritten.

## Updated candidate: reload and current execution

The old runner was removed with its matching old plugin before the update. The
updated asset was saved as a local plugin; installed Script source exactly matched
`dbd8c666…`. The demo was saved separately, then a filesystem copy under ignored
`.tools/commercial-20261017/RA10-DemoQA.rbxlx` was opened after a Studio restart.
Only the new owned runner was installed in that disposable copy.

`reload-previous-report.png` shows the restored report explicitly labeled
**SAVED REPORT — previous run**. Loading the saved plan restored its project key
and all definitions. A fresh native comparison produced
`snapshot-report-0ffda778.json`, PASS 5/5 against the preserved original baseline,
with Reward 12 versus baseline 10 within the configured range. See
`reload-baseline-current-pass.png`.

| Updated complete plan | Join / spawn / latejoin seconds | Outcome |
| --- | --- | --- |
| `smoke-20261017T203128Z-7d023242.json` | 9.994 / 10.659 / 27.149 | PASS 3/3; native windows closed without manual Stop. |
| `smoke-20261017T203414Z-c9ba394a.json` | 11.822 / 11.320 / 24.179 | PASS 3/3; native windows closed without manual Stop. |
| `smoke-20261017T203653Z-779fe977.json` | 10.294 / 11.296 / 24.255 | PASS 3/3; native windows closed without manual Stop. |

All three consecutive updated-build plans completed: nine distinct cases PASS,
each latejoin 1→2 with the initial player retained and exactly one new player.
No manual Stop, plugin reload, runner edit or Studio restart occurred between
these plans. Resource samples returned to one Studio process after each plan.

## Updated candidate: custom authoring, export and recovery

The interface was used to add the sixth assertion, **Door stays anchored**:
`Workspace/RA_Demo/Door`, property `Anchored`, equals boolean `true`. Save confirmed
local readback; `snapshot-plan-custom-anchored.json` preserves the definitions.
Comparison with the five-check baseline was refused before a native launch.
`snapshot-report-ce80ce9a.json` then passed all six checks, and the UI captured
`snapshot-baseline-ce80ce9a.json` from that successful run.

| Actual run | Outcome |
| --- | --- |
| `snapshot-report-2e572031.json` | FAIL, all six objects missing at the checkpoint: intentionally unanchoring the Door allowed it to fall out of the runtime world. The edit-mode Door remained present. |
| `snapshot-report-d5b5dc35.json` | FAIL, three specific value regressions after re-anchoring: CanCollide false, Unlocked false and Mode Closed. Object/range/Anchored passed. |
| `export-ui-d5b5dc35.json` | PASS export: Select JSON → Ctrl+C → new blank Notepad document → paste → Save As. Saved text exactly equals that real report, including its run identifier. |
| `snapshot-report-5b94df9a.json` | FAIL, reproducible infrastructure timeout with CharacterAutoLoads false: one player, zero characters with Humanoids. Native session finished automatically. This attempt did not establish Cancel. |
| `snapshot-report-e913e700.json` | FAIL, deliberate Cancel during a separate 90-second no-spawn run. UI confirmed cancelled results; the server remained responsible for native completion. |
| `dbd8-cross-mode-launch-refused.png` | PASS protection: switching to Smoke and clicking Run while the cancelled native session was pending/settling was refused; no overlapping session launched. |
| `snapshot-report-862743e8.json` | PASS, six-check baseline comparison after restoring CharacterAutoLoads and demo values. No Studio restart or manual Stop was needed for timeout/Cancel recovery. |

The baseline was retained through these failures. Screenshots with corresponding
`custom-*` and `dbd8-*` names show the real interface. The setup command initially
used a nonexistent demo marker name and asserted before any mutation; it was
corrected to the demo's actual `RegressionArenaDemoVersion` marker. This was an
authoring-command error, not a plugin execution result.

`dbd8-invalid-property-refused.png` records entering `Source` as a property and
clicking Add: the editor refused it with an actionable error and launched no test.
The saved six-check plan was not changed.

`dbd8-ordinary-play-inert.png` records an ordinary F5 Play session. After more
than a minute, a read-only server Command Bar check confirmed RunService running,
the enabled owned 1.0.0 runner, `GetTestArgs()` successfully returning nil, one
player and unchanged Door collision. The runner did not end this unmarked session.
Shift+F5 then ended this ordinary Play intentionally; this was not one of the
automatically completed acceptance plans. Roblox CorePackages client warnings
were visible; no Regression Arena error was reported in this check. Published
runtime remains UNVERIFIED and was not inferred from ordinary Play.

## Resources and scope

`resources.csv` samples available RAM, system CPU, Studio process count, working
set and responsiveness approximately every 10 seconds. A gap separates the first
candidate tests and the resumed evening work. Phase labels are operator labels,
not engine-generated verdicts. Four Studio processes here mean editor + server +
two clients, **not four players**. No four-client or two-initial-player test was
launched during this commercial validation. Early samples reached 274 MiB free;
native startup is resource intensive. No broader hardware support is inferred.

The acceptance matrix remains authoritative for outstanding checks. Features
without real execution remain UNVERIFIED; real faults remain FAIL even when they
are expected negative tests. These files do not establish seller eligibility,
published-game validation, Roblox moderation approval or publication authorization.
