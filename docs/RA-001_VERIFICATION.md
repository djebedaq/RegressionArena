# RA-001 verification record

Date: 2026-10-13. Branch: `codex/ra-001-v0.2`. Base: `main` at `ad5da6b403d9307464f221206cafeb3cdf968f1c`.

## Outcome and scope

The v0.2 source is prepared for review, with safer runner ownership/rollback, a strict per-run protocol, bounded scenario deadlines, cancellation/unload recovery, a configurable Test Plan, one local preset and bounded local history. No plugin/place publication or merge was performed.

Acceptance **A is verified offline**. Acceptance **B–G is UNVERIFIED in Roblox Studio**. The code must not be described as production-ready. A Studio process was detected, but this agent had no native UI control and did not execute Studio tests.

## Files and reasons

| Files | Reason |
| --- | --- |
| `src/Protocol.luau` | Shared request/plan/result validation; identity/config checks; measured PASS evidence and sanitized fields. |
| `src/RunnerCore.luau` | Engine-independent join, spawn and latejoin assertions with one deadline and retained-player checks. |
| `src/Session.luau` | One pending native call; protected response handling, watchdog, cancellation, cleanup, late-response rejection. |
| `src/RunnerManager.luau` | Exact ownership/version/source/editor checks, idempotent install/repair and reversible removal with rollback. |
| `src/Settings.luau` | Bounded restoration, whitelisted summaries, count/byte limits and verified settings writes. |
| `src/TestRunner.server.luau` | Studio/server/argument guards, protected engine boundary, single EndTest attempt and diagnostic watchdog. |
| `src/RegressionArena.plugin.template.luau` | Scrolling Test Plan UI, per-case timeouts, preset/history, Cancel, Remove and suite error recovery. |
| `scripts_build.py`, generated `dist/RegressionArena.plugin.luau` | Deterministic UTF-8/LF packaging, explicit marker/delimiter validation and complete embedded modules. Dist is rebuilt, never manually edited. |
| `tests/test_package.py`, `tests/test_integrity.py`, `tests/test_luau.py` | Packaging/guardrail tests, syntax checks and CLI mock-test orchestration. |
| `tests/luau/Support.luau`, `Protocol.spec.luau`, `RunnerCore.spec.luau`, `Session.spec.luau`, `RunnerManager.spec.luau`, `Settings.spec.luau`, `RunnerBoundary.spec.luau` | Actual Luau modules and generated server boundary run against deterministic mock services and time. |
| `.github/workflows/python-checks.yml` | Python build/integrity, pinned official Luau developer tools with checksum, compiler/mock execution and generated-diff gate. |
| `.gitattributes`, `.gitignore` | Stable LF files and exclusion of local developer binaries/caches. |
| `README.md`, `docs/API_AUDIT.md`, `docs/STUDIO_VALIDATION.md`, `docs/CODEX_TASK.md` | Install/run/update/remove procedure, API contexts/assumptions, runtime steps and current task status. |
| `docs/RA-001_VERIFICATION.md`, `docs/RA-001_TEST_LOG.txt` | Candid review evidence and exact captured command output. |

## Automatic checks actually executed

- `python scripts_build.py`: exit 0, generated the distribution successfully.
- `python -m unittest discover -s tests -v`: **18 tests, OK, zero skips**. Includes 69 executed Luau mock cases across six groups, plus syntax compilation of all seven source files and both rendered contexts (nine inputs). These are not Roblox execution tests.
- `git diff --check`: exit 0.
- A byte comparison against the checked-in generated artifact is included in the test suite; CI also rejects a rebuilt distribution that differs from the commit.

Exact stdout/stderr, timing and exit statuses are in [RA-001_TEST_LOG.txt](RA-001_TEST_LOG.txt). Python 3.14.6 and official Luau CLI 0.742 were used on Windows. The local Windows release ZIP SHA-256 was `1114966cd8198f407069f07e8b4e6bacf2ded933e4a57d6ddc75617969278c75`. CI pins the Linux release SHA-256 `152058b98c60ff1f5b5ec9bca0b8eb37793cae161dd3a05608cc3d8738ba1a4d`. Developer binaries are ignored, not shipped.

The mock cases prove reproducible *logic-level* failures for disabled spawning, player replacement, API exceptions, malformed/stale evidence, ignored cancellation, late completion, ownership collisions and settings corruption. They do not prove Roblox API behavior, permissions, multiplayer windows, client startup, real serialization, Undo or actual production inertness.

## Required human validation and known risks

Follow [STUDIO_VALIDATION.md](STUDIO_VALIDATION.md), including all 1/2/4-player matrices, a real `CharacterAutoLoads=false` failure, two consecutive suites, cancellation/reload, collision/Undo tests, preset/history reload and developer fault fixtures. Every ST-01–ST-15 result is UNVERIFIED and no runtime evidence is attached.

The main unresolved platform assumptions are server access to StudioTestService methods, request/result transport, GetTestArgs startup timing, edit-mode transitions, AddPlayers and LeaveTest behavior, plugin Unloading, script permissions/editor source and recording semantics. A native engine hang can require Studio Stop or reopening the disposable place. The plugin blocks overlapping calls while an old native call is known to be outstanding.

The plugin's own code does not use network/data-store/payment APIs, but game scripts still run and can have side effects; use an isolated place without production data/integrations. Old, modified or untagged runners require manual preservation/migration rather than automatic replacement. Custom character systems without parented Humanoids fail the current smoke assertion by design.

No paid-feature proposal is made yet: RA-001 places that decision after the real Studio-validation gate.
