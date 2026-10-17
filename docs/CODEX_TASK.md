# Codex Task RA-001 — ship a trustworthy v0.2 prototype

**Status:** RA-001 is under review with actual Studio 0.742 evidence in `RA-001_VERIFICATION.md` and `studio-evidence/README.md`. The gate has NOT passed: 1-player suites pass, all three 2-player cases have positive evidence across separate runs, but 4-player tests fail. Disabled spawning, Cancel recovery and ownership/Undo checks have engine evidence; remaining subcases are explicitly UNVERIFIED in `STUDIO_VALIDATION.md`. Do not call this production-ready or implement the paid layer.

## Objective

Turn the existing v0.1 source into a stable, testable Roblox Studio plugin that can reliably run multiplayer smoke tests locally, report real failures, and recover cleanly after errors. This is NOT a request to ship a paid product or add generic AI features.

## User problem

A Roblox creator has modified a game and wants an immediate answer to: "Did joining, spawning, and late joining still work for several players?" The value is repeatable tests and useful failure evidence, not a nicer button for Roblox's stock test launch.

## Scope: work in this order

### Phase A — audit for actual correctness (priority 1)

1. Inspect the entire v0.1 project and compare all `StudioTestService` calls against official API signatures and execution context restrictions.
2. Identify and repair incorrect/fragile assumptions in plugin-to-server lifecycle, serialized arguments, the `EndTest()` result, test session cleanup, runner installation and repeated runs.
3. Ensure failed API calls, malformed responses, timeouts, and unexpected plugin shutdown do not produce PASS or leave the UI stuck.
4. Confirm runner never runs during published production sessions. Add clear, reversible `Install/Update` and `Remove Test Runner` behaviors.
5. Make install/update idempotent and avoid changing unrelated scripts. Never auto-overwrite a script whose name matches but whose identity/version is not ours.

### Phase B — one real differentiator (priority 2)

Implement a small, configurable **Test Plan** instead of only hard-coded smoke checks:
- Select tests individually (join, spawn, late-join).
- Support a bounded configurable timeout for each case.
- Allow saving at least one local preset without modifying game assets.
- Give useful evidence when a test fails: scenario, expected, observed, elapsed, and actionable next check.
- Preserve the no-server/no-account/offline constraint.

Avoid building an AI chatbot, recorder, remote cloud test system, or sales/licensing logic.

### Phase C — developer quality (priority 3)

- Keep implementation small and modular in `src/`; generated `dist/` must be deterministic.
- Add meaningful static unit tests where Studio cannot run in CI, not only checks for the existence of method names.
- Use a basic GitHub Actions workflow for Python build/integrity tests.
- Document the exact install/test/update/remove process.
- Keep the default UI usable on a modest laptop screen.

## Acceptance criteria (all required, with honest evidence)

A. `python scripts_build.py` completes with no missing markers; `python -m unittest discover -s tests -v` passes. These alone do **not** validate execution.

B. In actual Roblox Studio (a human-run validation if agent lacks access): 1, 2, and 4 player modes complete `join`, `spawn` and `late-join` scenarios. Show PASS only if explicitly proven. Handle unexpected return values as FAIL.

C. In a test-place copy with `Players.CharacterAutoLoads = false` and no custom character loader, spawn case fails with understandable diagnosis, rather than giving a false PASS.

D. Run the suite twice back-to-back; no duplicate runners, hanging sessions or stale PASS results.

E. Open a published game in Studio / normal runtime: runner remains inert outside Studio test sessions; optional Remove action restores the place without changing unrelated content.

F. Deliberately invoke an invalid or timed-out scenario; UI recovers, reports the failure and allows another test.

G. Results persist locally, are bounded in count, and can be copied/used without external network calls. Do not collect game source code or personal information.

## Validation transparency

If Roblox Studio is unavailable in Codex's environment, implement and run A, document B–G as **NOT YET VERIFIED** with explicit steps in `docs/STUDIO_VALIDATION.md`, and stop short of calling the plugin production-ready.

## Product decision / strict no-feature-creep policy

When the core works and is manually validated, produce a concise follow-up proposal for ONE distinct paid feature that Roblox Studio does not provide out of the box (e.g., repeatable project-specific assertions and actionable difference reports). Do not implement the paid layer in this task without a validation gate.

## Deliverable

A GitHub pull request / ready-to-commit source containing reviewed Luau code, deterministic build, tests, installation guide, and a candid validation checklist. Include manual actions needed to test in Studio.
