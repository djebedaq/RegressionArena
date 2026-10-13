# Roblox Studio validation checklist — NOT YET RUN

This checklist exists because the current development environment does not run Roblox Studio. All cases start in a COPY of a game/place. Use current Roblox Studio with plugin debugging enabled.

| ID | Action | Expected | Evidence | Result |
| --- | --- | --- | --- | --- |
| ST-01 | Install as Local Plugin from `dist/RegressionArena.plugin.luau` | Toolbar button and widget appear; no errors in Output | screenshot / Output log | NOT RUN |
| ST-02 | Install/update test runner twice | One versioned runner exists; no duplicate/unrelated scripts changed | Explorer screenshot | NOT RUN |
| ST-03 | Run join with 1, 2, 4 players | Clear PASS with correct player counts | report JSON | NOT RUN |
| ST-04 | Run spawn with 1, 2, 4 players | PASS when normal character spawn succeeds | report JSON | NOT RUN |
| ST-05 | Run latejoin with 1, 2, 4 players | Clear PASS with one player added | report JSON | NOT RUN |
| ST-06 | In copy set `Players.CharacterAutoLoads=false` without custom loader; run spawn | FAIL with specific expected/observed info | report JSON | NOT RUN |
| ST-07 | Run suite twice; then simulate interruption/timeout | Recovers, no stuck UI, no false PASS | Output log | NOT RUN |
| ST-08 | Launch ordinary playtest without RA marker | No interference from RA runner | Output log | NOT RUN |
| ST-09 | Remove runner from plugin | Only RA-owned runner removed; normal code untouched | Explorer screenshot | NOT RUN |
| ST-10 | Check published game runtime with runner accidentally present | Runner inert outside Studio | Output log | NOT RUN |

Procedure:
1. In Roblox Studio, select a disposable test place (never your live production place).
2. Enable Plugin Debugging Enabled in Studio settings.
3. In `ServerStorage`, create a temporary Script with the generated `dist/RegressionArena.plugin.luau` source; use `Plugins > Save as Local Plugin`. Delete the temporary Script afterwards.
4. Open the plugin from its toolbar and execute ST-01 through ST-10.
5. Paste the exact error/output messages back into Codex for repair. Mark each test PASS/FAIL only after seeing the real behavior.
6. Do not submit for paid sale before the full checklist is complete.
