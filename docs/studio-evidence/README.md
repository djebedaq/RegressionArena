# Computer Use evidence — 2026-10-13

Actual Roblox Studio **0.742.0.7421053**, Windows, in the disposable, unpublished local `RA-v02-Baseplate.rbxl` under ignored `.tools/studio-validation/`. The plugin was installed using **Plugins > Save as Local Plugin**. No game or plugin was published. Final documentation and restart checks continued on 2026-10-14.

These 19 reports are exact JSON strings read from Regression Arena's local history after observed UI runs, with one trailing newline added. Filenames contain UTC plan-start time, initial player count and the first request nonce. Counts and generated identifiers are retained; no player identities or game source are included. A plan's start time is not its completion time. Failure reports and explicitly not-run cases are preserved.

**The acceptance gate has not passed.** Current-build one-player suites passed, and each two-player scenario has positive evidence across separate runs. Four-player attempts failed and full two-player suites encountered native timeouts. The [complete ST-01–ST-15 matrix](../STUDIO_VALIDATION.md) records partial and UNVERIFIED subcases. [Offline checks](../RA-001_TEST_LOG.txt) are separate from engine execution.

## Build attribution

- **Early:** development build; exact installed distribution hash UNVERIFIED. Do not attribute these first three plans to the final build.
- **Intermediate:** distribution SHA-256 `faacd4dc6550d7e31862df514af4454088d29ea1bfd3d1bcc3eea652399d2a8c`; includes three-second stable edit recovery and 60-second default, before the expanded 180-second range and bounded argument retry.
- **Current:** distribution SHA-256 `b720bc1fad06863421b99feaa278039b52ab9a9788ea070e702d95cba64d6b97`; matches the generated distribution. Installed local-plugin Source was checked against it, allowing the final newline added by Studio.

## Exact plan reports

PASS counts below describe the plugin's report. A deliberately failing fixture passes its validation only when the reported case fails correctly.

| UTC start / JSON | Build | Plan | Report | Observed outcome |
| --- | --- | --- | --- | --- |
| [13:29:10](run-20261013T132910Z-2p-44181985.json) | Early | 2p, all, 20s | 0/3 | Join/spawn observed 0 players; latejoin watchdog. |
| [13:39:47](run-20261013T133947Z-1p-7aca9e47.json) | Early | 1p, join, 60s | 1/1 | Join PASS, 18.34s. |
| [13:43:23](run-20261013T134323Z-1p-aec26b5d.json) | Early | 1p, all, 60s | 1/3 | Join PASS; next case unexpected transport at 1.53s; latejoin not run. Delayed previous Stop observed; UI End Session required. |
| [13:58:38](run-20261013T135838Z-2p-de993c40.json) | Intermediate | 2p, all, 60s | 2/3 | Join/spawn PASS, 41.50/35.82s; latejoin watchdog 236.05s. Argument handoff timeout observed; UI End Session used. |
| [14:19:21](run-20261013T141921Z-4p-7fc8815d.json) | Intermediate | 4p, all, 60s | 0/3 | Join deadline, 0 players; spawn watchdog; latejoin not run. |
| [14:26:05](run-20261013T142605Z-1p-ab5ff388.json) | Intermediate | 1p, all, 60s | 3/3 | 14.18/8.60/31.63s; latejoin 1→2, one added, initial retained. All native windows closed automatically. |
| [14:28:24](run-20261013T142824Z-1p-0cea0fad.json) | Intermediate | 1p, all, 60s | 3/3 | Consecutive repeat: 8.63/9.42/27.77s, fresh nonces, automatic cleanup. |
| [16:05:20](run-20261013T160520Z-2p-308b933b.json) | Current | 2p, all, 180s | 2/3 | Join/spawn PASS, 131.17/52.83s; latejoin watchdog 222.57s. Overlapping Run refused. Native windows ended later. |
| [17:08:30](run-20261013T170830Z-2p-ed07de43.json) | Current | 2p, latejoin, 180s | 1/1 | PASS, 92.64s; 2→3, one added, initial retained; automatic cleanup. |
| [17:15:41](run-20261013T171541Z-4p-60f2f6e3.json) | Current | 4p, latejoin, 180s | 0/1 | Watchdog, 219.94s; no verified latejoin counts. |
| [17:24:04](run-20261013T172404Z-4p-41b92bfc.json) | Current | 4p, join, 180s | 0/1 | FAIL, only 2/4 players after 180.07s. Built-in ExplorerPlugin unresponsive prompt observed; automatic session cleanup. |
| [17:31:57](run-20261013T173157Z-1p-80a3dab2.json) | Current | 1p, all, 180s | 0/3 | Unexpected nil transport, 89.15s; remaining cases not run. Cancel input delivery was unknown, so Cancel is NOT verified by this report. Studio restarted afterward. |
| [17:45:04](run-20261013T174504Z-2p-7bc6100a.json) | Current | 2p, spawn, 5s | 0/1 | CharacterAutoLoads=false; expected FAIL at 5.0005s, but 0 players makes loader diagnosis weaker. |
| [17:48:31](run-20261013T174831Z-2p-73c9cc21.json) | Current | 2p, spawn, 180s | 0/1 | Strong negative: 2 players, 0 ready characters; correct diagnosed FAIL at 180.0117s; automatic cleanup. |
| [18:11:57](run-20261013T181157Z-1p-9c721dab.json) | Current | 1p, all, 60s | 0/3 | Real startup Cancel confirmed in UI; result discarded, remaining cases not run. Server ended later; initial retry refused during stable edit recovery. |
| [18:14:45](run-20261013T181445Z-1p-956b1f6b.json) | Current | 1p, all, 60s | 3/3 | Healthy recovery after Cancel: 17.06/11.10/55.40s; automatic cleanup. |
| [18:32:37](run-20261013T183237Z-1p-50aea42f.json) | Current | 1p, malformed fixture, all, 60s | 0/3 | Deliberately invalid EndTest JSON rejected at 16.88s, replacing earlier PASS; remaining cases not run. |
| [18:39:38](run-20261013T183938Z-1p-64d67f51.json) | Current | 1p, stale replay fixture, all, 60s | 0/3 | Actual earlier join PASS from 18:14:45, with old nonce, rejected at 24.53s; remaining cases not run. |
| [18:47:38](run-20261013T184738Z-1p-17b6fa54.json) | Current | 1p, all, 60s | 3/3 | Final healthy baseline after fixture cleanup: 17.10/12.68/33.64s; latejoin 1→2, one added, initial retained; automatic cleanup. |

Lua deadlines are cooperative. Engine scheduling stalls caused elapsed values greater than configured budgets; reports preserve those values. Native startup responsiveness failures on this 8 GiB machine are observed symptoms, not a proven root cause or proof that hardware upgrades would solve the four-player failures.

## Other actual engine checks

- Install twice/repair: exactly one enabled, Legacy, tagged v0.2 runner. Real UI Remove/repeat/Undo/Redo preserved matching Source and an unrelated sentinel.
- Developer ownership integration: first command-bar attempt refused ChangeHistoryService recording, ran 0/9 and preserved the baseline. The same actual RunnerManager executed as a local validation plugin passed **9/9** engine checks. This is not proof of actual script-permission denial or unsaved editor divergence.
- Ordinary Run, Play and one-client Server and Clients: observer printed nil RA arguments and an active server. No RA errors/interference observed; sessions stayed active until manual UI Stop/End Session. Play screenshots with account names were not retained.
- Settings: preset 127 bytes restored after local-plugin reload; 19 plans collected over the session, live history retained 10 entries, largest observed report 1549 bytes. Previous report was explicitly labeled. Run and Save refused timeout 181; Load restored 60 without overwriting the preset.
- Cleanup before the last healthy suite: exact baseline Source intact, ServerScriptService child count 1, ServerStorage child count 0. NoAutoSpawn, Observer, sentinel and the ownership container restored by Undo were detached. Only the baseline runner remained in the saved local place. The temporary ownership validation plugin was reversibly renamed with `.disabled` before restarting Studio.
- Restart check on 2026-10-14: opened the exact saved local file through Studio's file dialog. Only the baseline Regression Arena toolbar was present; no validation button or active native test remained.

[Sanitized engine events](engine-events.txt) contain selected Studio test lifecycle messages and `RA_VALIDATION` Output. Raw logs, user IDs, network addresses, tokens and unrelated app content are not committed. Process identifiers are redacted. Events corroborate execution but are not a complete engine log.

Developer fixtures and reproduction steps are in [STUDIO_VALIDATION.md](../STUDIO_VALIDATION.md). They are excluded from the shipped distribution. Published-runtime testing, actual permission denial, live unload and other unfinished subcases remain explicitly UNVERIFIED.

## Screenshots

- [Install / repair count](ST-02-install-idempotent.png)
- [Four-player native Explorer responsiveness failure](ST-03-4p-native-explorer-unresponsive.png)
- [Intermediate one-player 3/3 suite](ST-07-1p-suite-pass.png)
- [Current-build 3/3 recovery after Cancel](ST-07-current-build-recovery-3-of-3.png)
- [Unmarked Run observer](ST-08-unmarked-Run.png)
- [Unmarked multiplayer observer](ST-08-unmarked-multiplayer.png)
- [Ownership plugin: 9/9 actual engine checks](ST-11-ownership-9-of-9.png)
- [Clean baseline after Studio restart](ST-12-clean-baseline-restart.png)
- [Healthy 3/3 after malformed and stale fixtures](ST-13-healthy-rerun-3-of-3.png)
- [Previous saved report label](ST-14-saved-previous-report.png)
- [Invalid timeout refused](ST-14-invalid-timeout-refused.png)
