# Commercial release phase 1 — 2026-10-17

Real Computer Use execution in Roblox Studio **0.743.0.7431133**, Windows, an
unpublished disposable local copy under `.tools/commercial-20261017/`. The original
validation place and all initial Git contents were backed up before this work.
No four-client or two-initial-player test, publication, security change or merge.

## Three consecutive complete plans

Installed plugin Source was read from its locally saved XML and matched the exact
distribution SHA-256 `b832f68555ae1ac2390e79cdd1de3d1080dce5bcba061ba6d38c05c636da6f06`.
Each plan used one initial player, all three cases, and 180-second budgets.

| UTC plan start | join | spawn | latejoin 1 to 2 | Result |
| --- | --- | --- | --- | --- |
| [14:50:02](run-20261017T145002Z-1p-23d2fdba.json) | 13.226s | 14.944s | 32.536s | 3/3 PASS |
| [14:52:29](run-20261017T145229Z-1p-826e1c12.json) | 10.456s | 11.422s | 24.445s | 3/3 PASS |
| [14:54:44](run-20261017T145444Z-1p-e589fae4.json) | 10.169s | 12.188s | 24.756s | 3/3 PASS |

Each JSON file is the exact plugin-history string plus a trailing LF. All nine case
identifiers are distinct. Every latejoin retained the initial player and observed
exactly one new player. No manual Stop, Cancel, plugin reload or fixture was used
between these three plans. Native windows closed automatically; passive samples
confirmed one remaining Studio process before each next plan. Config and completion
screenshots are `plan-1-config.png` and `plan-1/2/3-complete.png`.

[UI action times](ui-actions.json), [selected engine events](engine-events.txt),
[120 passive samples](resources.csv) and [calculated resource summary](resource-summary.json)
corroborate execution. Minimum measured free RAM was 333 MiB, peak system CPU 100%,
maximum four Studio processes and zero reported unresponsive processes. Sampling
includes idle periods and cleanup; private commit is not resident RAM. These
observations do not establish the engine root cause or guarantee future runs.

The earlier RA-001/RA-002 failures remain valid historical evidence. This is a
successful repeat on Studio 0.743 and the exact recovery build, not proof that an
unreleased 1.0 package passed. Two initial players and four-client support remain
unverified and are excluded from the intended first supported release.

## Late native-transport regression

[Actual Luau mock reproduction](late-transport-regression.txt): the preserved
preflight source fails when a nil native result arrives after the watchdog; the
fixed Session passes 20 cases, including cancellation followed by a late table.
Classification now happens in the completion coroutine even after run() returned.
These mock checks are not Studio execution. Real delayed-table verification of
safety build `9b56d8bb360e95bf31d27dd5949666a31d20d2dbc0e9737b2e2f832f8a89ac0c`
has real delayed-table evidence below.

The isolated server fixture disabled only its owned runner clone, waited 65 seconds,
then supplied a table as the sole result. The plugin reported 0/1 FAIL through the
watchdog at 55.064 seconds before that result arrived. Native EndTest later closed
the windows automatically. Two Run attempts after closure, separated by more than
the settling interval, both refused and required Studio restart. No second native
launch occurred. See [actual fault report](run-20261017T150520Z-delayed-table.json),
[engine events](delayed-table-engine-events.txt), [configuration](delayed-table-config.png),
[watchdog](delayed-table-watchdog.png), [refusal](delayed-table-quarantine.png) and
[repeat refusal](delayed-table-second-refusal.png). This directly exercises a late
invalid result after run() has returned, not an immediate malformed result.

Cleanup first refused because the developer comparison omitted the embedded runner
literal's trailing LF. Read-only diagnosis showed the runner enabled, its editor
Source equal to Source, and 11318 bytes. Correcting only that comparison allowed
exact-source cleanup. At 15:10:32.756Z, Output confirmed place 0, edit=true,
runner enabled and unchanged, one server Script, empty ServerStorage, fault detached.
The disposable file was saved on normal Studio exit. The old original place was
not overwritten. [Final edit evidence](safety-final-clean-edit.png).

Saving that safety build as the same local plugin successfully replaced its XML
Source, verified exactly against dist. The toolbar disappeared after automatic
reload without a reported plugin error; changing ribbon tabs did not restore it.
Studio was closed normally, saving only the disposable place (with its clearly
named pending developer fault fixture), then relaunched. This update/reload
behavior is not considered a passed upgrade test.

Raw logs, account identifiers, unrelated process information and credentials are
not included. The production runner Source remained unchanged during these tests.
