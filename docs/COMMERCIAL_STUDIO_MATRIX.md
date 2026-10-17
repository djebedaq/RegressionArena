# Regression Arena 1.0 candidate — Studio acceptance matrix

This matrix concerns the production asset, not the historical 0.2 recovery build.
An automated mock PASS does not establish a Studio PASS. Update outcomes only
after the corresponding real UI/engine execution and preserve its evidence.

Environment: Windows, Roblox Studio 0.743.0.7431133, 8,127 MiB visible RAM.
Only one initial player is supported. Latejoin adds one more client. Never launch
four-client tests on this machine. Two initial players remain excluded.

| Scenario | Required evidence | Current status |
| --- | --- | --- |
| Load the standalone `dist/RegressionArena.rbxmx` and save as a local plugin | Studio UI; installed Script source equals generated source | PASS, candidate `3b9fa332` |
| Clean Baseplate before runner installation | PlaceId 0, edit mode, SSS 0, ServerStorage 0 | PASS, `RA10_CLEAN_BASEPLATE` Output |
| Install 1.0 runner through Setup | Exactly one owned, versioned runner; Undo recording | PASS initial and updated candidate installation UI; real ownership/Undo audit on initial candidate |
| Repeated installation | Same runner instance; no duplicates | PASS initial candidate, same instance/Source verified |
| Smoke join + spawn + latejoin, complete plan | Current validated JSON, native windows close without manual Stop | PASS initial candidate and three consecutive updated `dbd8c666` plans, 9/9; no Stop/reload/restart between plans |
| Create custom assertions through the interface | Saved plan and matching real result | PASS, sixth custom Anchored boolean assertion; saved plan, ce80ce9a PASS 6/6 and successful baseline |
| Load demo definitions and run all five assertions | Current successful engine report | PASS initial candidate; updated candidate restored plan and fresh 5/5 comparison |
| Capture successful local baseline | Read-back-verified settings and UI | PASS `snapshot-baseline-3c365e02`; failed capture refused |
| Rerun matching baseline | Current comparison with baseline values | PASS both candidates; updated `snapshot-report-0ffda778` |
| Deliberately change CanCollide/Unlocked | FAIL with actual false, expected true and specific reasons | FAIL correctly detected, plus Mode Closed; initial 9be98f5a and updated d5b5dc35; other three updated checks PASS |
| Change Reward within the allowed range | PASS without exact-value false positive | PASS both candidates, actual 12 versus baseline 10 in [5,15] |
| Restore the intentional fault | New PASS, original baseline retained | PASS initial `17efc6c1` and updated reload `0ffda778` |
| Reject invalid input and mismatched project/plan | No native launch; useful message | PASS updated plan mismatch refusal and Source property rejected by actual editor; no native launch |
| Export selected JSON into a local file | Actual UI copy/paste output equals current report | PASS actual Select JSON/Ctrl+C/Notepad/Save As; export-ui-d5b5dc35 exactly matches current report |
| Reload plugin/Studio | Plan, successful baseline and previous-report labels persist | PASS updated `dbd8c666` after restart; previous-report label and fresh baseline comparison |
| Cancel, timeout and recover | No stale PASS; correct shared native ownership | PASS updated candidate: no-spawn timeout 5b94df9a, Cancel e913e700, cross-mode Run refused, recovery 862743e8 PASS 6/6 without restart/Stop; late invalid transport separately proven on 0.2 safety build |
| Remove / Undo / reinstall | Only exact owned runner affected, demo content intact | PASS initial real Remove/Undo/reinstall; latest runner installed cleanly after update |
| Collision, edited or older runner | Refused mutation; original object intact | PASS initial edited runner and foreign Folder refusal for both actions; unsupported-version mocks PASS |
| Ordinary Studio Play | Unmarked runner remains inert | PASS updated candidate F5 Play remained active; server confirmed enabled owned 1.0 runner and GetTestArgs nil; ended intentionally with Shift+F5 |
| Published runtime inertness | Not inferred from Studio or mocks | UNVERIFIED; no publication authorized |
| Small and large panels | Readable controls, scrolling, results and errors | Large floating panel PASS updated; old narrow clipping was corrected in source, small-panel runtime still pending |

The release gate remains BLOCKED until critical product scenarios pass and the
remaining limitations are explicitly recorded in the release report.
