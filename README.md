# Regression Arena 1.0 — release candidate

Regression Snapshot records explicit expectations for Roblox server state and
compares a fresh run with a successful local baseline. Create checks for object
presence, supported properties and Attributes: exact primitive values or inclusive
numeric ranges. Results show PASS/FAIL, expected and actual values, and reasons.

**Release gate: work in progress.** The production asset and buyer ZIP exist;
remaining Studio acceptance and GitHub CI must pass before a READY decision. No
Creator Store publication, paid listing or release-PR merge has been authorized.
See [release status](docs/COMMERCIAL_RELEASE_STATUS.md) and the
[Studio acceptance matrix](docs/COMMERCIAL_STUDIO_MATRIX.md).

## Start here

- [Buyer guide: install, configure, baseline, export, remove and recover](release/BUYER_GUIDE.md)
- [Clean demonstration project](demo/README.md)
- [Real Studio evidence, with build identities](docs/commercial-v1-evidence/README.md)
- [Creator Store draft](release/CREATOR_STORE_DRAFT.md), [pricing research](release/MARKET_AND_PRICE.md), [compliance review](release/COMPLIANCE.md)

Open `dist/RegressionArena.rbxmx` in Studio, select its single RegressionArena
Script and choose **Plugins > Save as Local Plugin**. Close that asset without
saving changes, then open a disposable local place copy. In Regression Arena's
Setup tab, explicitly install the owned 1.0 runner. Load the demonstration plan
from Snapshot while using a copy of `demo/RegressionArena-Demo.rbxlx`.

Use stable values and a project key unique to your place. At most 16 assertions,
one local plan, one successful baseline and one last Snapshot report are stored.
Smoke retains up to ten reports. Export JSON by selecting it in Results, Ctrl+C,
and pasting into a local file. No importing arbitrary plans or headless CI runner
is included. The detailed guide lists supported paths, properties and limits.

## Supported scope

**One initial player; Smoke latejoin to two clients.** Smoke checks join, spawn
and retained initial players with one new latejoin identity. Snapshot reads server
state once after spawning and the configured checkpoint delay. It does not prove
client UI/gameplay readiness or detect every bug. Two initial players and
four-client mode are excluded. No four-client test is repeated on this machine.

The product is offline-first with no AI API, telemetry, remote HTTP endpoint,
subscription, custom payment/licensing system or remote executable dependency.
Ordinary Studio networking for native multiplayer tests still applies. Game scripts
still execute: use a disposable copy with live data access, purchases and external
integrations disabled by you. This plugin does not sandbox game behavior.

Setup installs only `ServerScriptService.RegressionArena_TestRunner`, explicitly
owned and versioned. Install/remove use Undo and reject unknown or edited content.
Before updating, remove the runner using the old matching plugin, then update the
plugin and install the new runner. Remove the runner before shipping a game.
Published-runtime validation remains UNVERIFIED; no game was published for testing.

Cancel discards results while the server still finishes. The shared native lock
prevents overlapping Snapshot/Smoke launches. Invalid native returns require a
Studio restart. The guide explains manual End Session and recovery.

## Build and developer checks

`src/` is the source of truth. Never edit generated `dist/` code manually.

```powershell
python scripts_build.py
python -m unittest discover -s tests -v
python scripts_release.py
```

The standalone plugin asset has exactly one readable Script. The deterministic
buyer ZIP contains that asset, a script-free demo, the buyer guide, instructions
and a hash manifest; no developer fixtures/debug/test files are included. GitHub
CI compiles generated Luau and runs mock/build/package checks. Python/Luau mocks
are **not Roblox Studio execution tests**. Real UI/engine evidence is recorded
separately with exact plugin hashes and all observed failures.

## Preserved development history

The previous v0.2 README, including recovery findings and local documentation work,
is preserved in [V02_README.md](docs/V02_README.md). Historical 1/2/4-player prototype
options are not current commercial support claims. Read [CODEX_TASK](docs/CODEX_TASK.md),
[STUDIO_VALIDATION](docs/STUDIO_VALIDATION.md), [API_AUDIT](docs/API_AUDIT.md),
[RA-002_DIAGNOSTICS](docs/RA-002_DIAGNOSTICS.md) and the newer
[Phase 1 evidence](docs/commercial-phase1-evidence/README.md) for the full record.
