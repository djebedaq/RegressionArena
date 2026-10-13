# Copy this as the initial Codex task

Read `AGENTS.md`, `docs/CODEX_TASK.md`, and `docs/STUDIO_VALIDATION.md` first. This repository contains a v0.1 prototype of an offline Roblox Studio plugin named Regression Arena.

Implement **RA-001** end-to-end on a new branch, then produce a pull request. Audit correctness against official Roblox `StudioTestService` docs, fix lifecycle and failure handling, add a safe runner removal feature, implement the narrow configurable Test Plan described in the task, and add reliable tests/build automation. Do not add cloud services, network calls, AI API, analytics, credential requests, licensing, marketing features, or unrelated refactors. Do not auto-publish anything.

Run `python scripts_build.py` and `python -m unittest discover -s tests -v`; include the exact logs/results. If Roblox Studio is unavailable, clearly distinguish static checks from manual runtime validation and leave all Studio cases explicitly UNVERIFIED in `docs/STUDIO_VALIDATION.md`. Provide exact manual test steps and list any API assumptions requiring verification in Studio.

Prioritize correctness, minimal maintenance, and a demonstrated reproducible failing test over UI polish.
