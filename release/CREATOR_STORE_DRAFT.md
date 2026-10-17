# Creator Store listing — draft, not published

**Name:** Regression Arena — Regression Snapshot

**Suggested price for owner approval:** $19.99 USD, one-time purchase.

**Short description:** Save explicit server-state checks. Rerun after a change and
see what passed, what failed and why — inside Roblox Studio.

## Description

Turn a repeatable check into a local regression baseline.

Regression Snapshot lets you define checks for named game objects, supported
properties and Attributes. Check presence, an exact boolean/number/string value,
or a deliberate numeric range. Run the plan after one player spawns, inspect the
results and save a successful baseline. After your next change, rerun and compare.

Each assertion shows PASS or FAIL, expected value, actual value and a specific
reason. Baseline comparisons include the previous observation. Numeric ranges
remain tolerances, so a valid number does not fail merely because it changed.

Included:

- An English Studio interface with scrolling Snapshot, Smoke, Setup and Results tabs.
- Up to 16 assertions per plan, with one local plan and successful baseline slot.
- Read-only assertions under Workspace, ReplicatedStorage, ServerStorage, Lighting
  and SoundService, using exact paths and supported primitive values.
- Multiplayer smoke checks for join, spawn and latejoin: one initial player,
  latejoin to a second client.
- Selectable JSON reports to copy into a local file, plus bounded local history.
- Explicit, reversible runner installation and removal with Undo.
- A local demonstration place and step-by-step buyer guide in the release bundle.

No subscription, AI API, telemetry, external server, remote code dependency or
custom licensing system. Ordinary Studio networking for native tests still applies.

Use a disposable local copy of your place. Your game's scripts still execute; the
plugin does not sandbox them. Snapshot checks server state at one checkpoint after
spawning. It does not test client-only UI, simulate gameplay input or guarantee
detection of every bug. Two initial players and four-client mode are excluded.
Cancellation discards results; the native server still finishes. Invalid native
returns require a Studio restart before another run. Remove the runner before
shipping your game. Read the guide for supported properties, limits and updates.

## Search terms

regression, testing, snapshot, baseline, assertions, smoke test, multiplayer,
latejoin, QA, Attributes, Studio, offline

## Media plan

Use only screenshots from the final working build. `media/snapshot-baseline-pass.png`
and `media/smoke-plan-pass.png` are direct, unaltered captures of the real plugin
window. `media/snapshot-regression-fail.png` shows the actual updated build detecting
three deliberately broken values, alongside three passing checks.
Do not imply an invented sales count, testimonial or certification. Before upload,
preview the chosen images in the Creator Store form; that moderation/upload step
remains unverified until the owner authorizes publication.

## 60–90 second demonstration script

1. Show the demo Door in Explorer and five explicit assertions in Snapshot.
2. Run the plan; show a real PASS and capture the successful baseline.
3. Turn CanCollide off, set Unlocked false and Mode `Closed` on the demo Door.
4. Rerun and compare; show three real FAIL rows and their actual values.
5. Restore the values; change Reward within 5–15 and rerun. Show the range PASS.
6. Show Select JSON for export and reversible runner removal.

Record actual native launches. If time is shortened in an edited video, label the
cut rather than presenting time-compressed footage as real test duration. No video
has been recorded at this checkpoint; the script is ready for recording.

## Owner publication checklist

Seller approval, account eligibility, individual asset ownership, age/identity,
2-step verification, supported region, Stripe/banking/tax status and media upload
eligibility are **UNVERIFIED**. The owner must complete/check these personally.
No identity, banking, tax or authentication data is needed by Regression Arena.
Final publication, paid pricing and release-PR merge require explicit owner approval.
