# Product strategy / go-no-go

**Candidate positioning:** Run multiplayer smoke checks inside Roblox Studio before you publish a game update.

## Phase 1: engineering gate
1. Verify plugin installs with no errors in current Studio.
2. Validate success and intentionally broken scenarios.
3. Verify repeated runs do not leak player windows or modify saved data.
4. Verify no false PASS on custom spawn workflows; display limitations clearly.
5. Add explicit cancellation/error recovery if tests do not terminate.

## Phase 2: differentiated paid functionality
- Custom test scenario API and recorder (not merely StudioTestService buttons).
- Repeatable test sequences, client event simulation and history diffs.
- Attach failure evidence and reproduce instructions.
- Permission-minimizing, offline-only operation.

## Commercial gate
- Research Creator Store competition again before paid launch.
- Release preview/demo to verify organic installs; marketplace placement is not guaranteed.
- Start pricing experiment at $24.99–$49.99 for genuinely differentiated paid functionality.
- No fixed-sales guarantee. At $39.99, 100 sales = $3,999 **gross**, not net income.
- Payouts may be delayed, and seller approval/tax information is required.
