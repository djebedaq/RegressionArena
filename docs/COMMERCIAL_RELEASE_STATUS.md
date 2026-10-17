# Regression Arena 1.0 commercial release work

User-authorized master task: 2026-10-17. Continue the existing project and preserve
all prior local work. Do not publish, set a paid public offer, merge the release PR,
or handle identity, banking, tax, authentication or security permissions for the user.

## Current release decision

**NOT READY — acceptance work in progress.** Snapshot, the English interface,
standalone 1.0 asset, clean demo, deterministic buyer ZIP and buyer/store drafts
are implemented. The latest package still needs the outstanding real Studio
checks and GitHub CI. No commercial readiness is claimed at this checkpoint.

## Phase 1 checkpoint

In Studio **0.743.0.7431133**, Windows, the exact installed recovery build
`b832f68555ae1ac2390e79cdd1de3d1080dce5bcba061ba6d38c05c636da6f06`
completed three consecutive one-initial-player plans on 2026-10-17. Every plan ran
join, spawn and latejoin to two clients at 180-second case budgets. All nine cases
passed with distinct identifiers; no manual Stop was used and native processes
returned to one between plans. See [new engine evidence](commercial-phase1-evidence/).
These observations belong to that build, not to a future 1.0 package.

The first supported configuration will be **one initial player, maximum two clients
including latejoin**. Two initial players require three complete consecutive plans
including latejoin to three; that evidence does not exist. Four-client testing is
excluded on this machine after prior critical RAM pressure. Older failures remain
preserved in RA-001/RA-002 evidence.

A newly reproduced Session defect allowed invalid transport arriving after watchdog
or Cancel to bypass quarantine through a later ready() call. Transport is now
classified inside the native completion coroutine. Two added mock regressions pass;
the preserved preflight source fails. An isolated real table result delayed beyond
the watchdog also verified failure, automatic native closure and repeated Run
refusal with the restart instruction. The exact temporary fixture was detached;
the baseline runner remained enabled and unchanged, and the local copy was saved.
The current generated safety build is
`9b56d8bb360e95bf31d27dd5949666a31d20d2dbc0e9737b2e2f832f8a89ac0c`.

[Offline log](COMMERCIAL_PHASE1_TEST_LOG.txt): build exit 0; 19 tests OK, no skips,
77 Luau mock cases and syntax compilation. These are not Studio runtime tests.

## Remaining master-task gates

1. Finish real custom-assertion authoring, JSON copy/export, error/cancel/timeout
   recovery, ordinary Play inertness and small-panel acceptance.
2. Preserve the completed latest-build reliability evidence: three consecutive
   full plans passed 3/3 each, without manual Stop, reload or restart between plans.
3. Run GitHub CI against a release branch and prepare the final release PR/report.
4. Finish evidence-backed media and release checklist, then decide READY or BLOCKED.

The [1.0 evidence index](commercial-v1-evidence/README.md) records the initial
candidate's clean Baseplate install, full 3/3 smoke plan, five demo assertions,
successful baseline, deliberate three-assertion regression, range tolerance,
restoration, real remove/Undo/ownership/collision checks, and the updated build's
successful reload/baseline comparison. Initial evidence belongs to `3b9fa332…`;
the updated installed source is `dbd8c666…`, exactly matching generated code.

Latest offline result: **22 Python checks OK, no skips**, including syntax and
100 Luau mock cases. The buyer ZIP is deterministic and its exact whitelist and
hashes are checked. These results are not Studio runtime proof. The
[buyer guide](../release/BUYER_GUIDE.md), [listing draft](../release/CREATOR_STORE_DRAFT.md),
[policy review](../release/COMPLIANCE.md) and [pricing research](../release/MARKET_AND_PRICE.md)
are prepared; the proposed $19.99 one-time price needs final owner approval.

Seller eligibility, seller approval, identity/age status, 2-step verification,
Stripe/bank/tax completion and asset/account rights are **UNVERIFIED**. No sensitive
account data is requested or collected by the plugin or this checkpoint.

## Workspace preservation

Branch at start: `codex/ra-001-v0.2`, HEAD `b31031a`, Draft PR #1. The initial eight
modified tracked files and untracked recovery evidence were copied, with SHA-256
inventory, to ignored `.tools/commercial-20261017/preflight-original/` before edits.
The old Baseplate was copied to a separate ignored local test file. No reset,
forced branch switch, publication or unrelated repository action was performed.
