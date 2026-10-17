# Regression Arena 1.0

Repeat a small, explicit set of server-state checks after a change to your game.
Regression Snapshot checks the objects, properties and Attributes you choose. It
does not discover every bug, play through your game, or verify client interfaces.

## First setup

1. Install the plugin through Roblox Studio's Creator Store. For a supplied local
   build, open `RegressionArena.rbxmx`, select the `RegressionArena` Script in
   Explorer, then choose **Plugins > Save as Local Plugin**. Close that asset
   window without saving changes. Restart Studio if the toolbar does not appear.
2. Open a disposable local copy of your place. Disable live data access, purchases
   and external integrations in that copy yourself. Your game's scripts still run
   in a Studio test; this plugin does not sandbox them.
3. Open **Regression Arena > Setup**. Choose **Install / repair owned runner**.
   This explicitly adds `ServerScriptService.RegressionArena_TestRunner`, version
   1.0.0. It is the only game object the plugin installs. Undo is available.
4. Start with the bundled demonstration place and plan below.

The supported configuration is **one initial player**. Smoke latejoin adds a
second client. Allow enough RAM for the editor, server and up to two client
processes. Two initial players and four-client mode are excluded from this release.

## Five-minute demonstration

Open a copy of `RegressionArena-Demo.rbxlx`. It contains a Baseplate, an anchored
door and a contract board, with no game scripts or preinstalled runner.

1. Install the runner through **Setup**.
2. In **Snapshot**, choose **Load bundled demonstration plan** and **Save local
   Snapshot plan**. Choose **Run Snapshot**. The five assertions should pass.
3. Return to **Snapshot** and choose **Capture current successful Snapshot as
   baseline**. A baseline can only come from a fresh, complete successful run.
4. In edit mode, select `Workspace > RA_Demo > Door`. In Properties, turn
   **CanCollide** off. Under Attributes set **Unlocked** to false and **Mode** to
   `Closed`. Leave **Reward** between 5 and 15.
5. Choose **Rerun and compare with baseline**. The changed boolean/property and
   string assertions fail, each with expected value, actual value and reason.
6. Restore CanCollide and Unlocked to true and Mode to `Open`. Set Reward to 12.
   Compare again. Reward passes within its configured range even if the baseline
   observed another number. A failed run cannot replace your successful baseline.

These are deliberate faults in the supplied demo objects. Do not change live game
data to reproduce them. The demonstration checks data contracts; the door has no
interaction script.

## Create your own assertions

Use a **Project key unique to your local place** and a descriptive plan name.
The plugin has one local plan slot, one baseline slot and one last Snapshot report
slot. Saving or capturing another plan replaces that slot. Export reports before
switching projects. The project key and exact definitions must match to compare.

Scroll down in **Snapshot** to the assertion editor:

1. Enter an assertion label and exact path, such as
   `Workspace/Checkpoint/Trigger`. Alternatively select one object in Explorer
   and choose **Use selected object's path**.
2. Cycle **Source** between object, property and attribute. For a property or
   Attribute, enter its exact key, including capitalization.
3. Cycle **Condition** between exists, equals and range. For exists, use a boolean
   expected value (`true` means present; `false` means absent). For equals choose
   boolean, number or string and enter the expected value. A boolean Attribute
   with value false is still present. Range uses inclusive minimum and maximum.
4. Choose **Add assertion**. Use **Select next assertion**, edit its fields and
   **Update selected assertion** to change it. Remove only the selected assertion
   with **Remove selected assertion**. Save the plan locally.
5. Run, inspect Results, and capture a successful baseline. After changes, rerun
   and compare. Changing any definition, project key, timeout or delay requires
   restoring the baseline's definitions or capturing a new successful baseline.

At most 16 assertions are allowed. Paths have at most eight names (including the
service), each at most 64 bytes; names cannot contain slashes or control characters.
Sibling names must be unique. Roots: Workspace, ReplicatedStorage, ServerStorage,
Lighting and SoundService. Attributes may hold booleans, finite numbers or strings
of at most 128 bytes. The same primitive restriction applies to property values.
Vectors, CFrames, Instances and other compound values are unsupported.

Allowed properties: Name, ClassName, Value, Anchored, CanCollide, CanTouch,
CanQuery, Transparency, Reflectance, Enabled, Brightness, ClockTime, Visible,
Active, Text, Volume, PlaybackSpeed, Looped, WalkSpeed, JumpPower, Health, MaxHealth.
An unsupported property, duplicate name, missing target or read error produces a
specific failure instead of a guessed match. Source code is never an assertion.

## Choose deterministic checks

Snapshot waits for exactly one server player with a parented character and Humanoid,
then waits your checkpoint delay (0–10 seconds). It reads each assertion **once**.
It does not wait for an expected value to become true. Use stable server state,
explicit game-owned readiness Attributes and deliberate numeric tolerances.
Avoid clocks, random rewards, moving positions and other unconstrained values.
Client-only GUI state and arbitrary player paths are outside this version's scope.

The session timeout is 5–180 seconds and includes joining/spawning. Keep 180 seconds
on slow machines; a very short timeout may expire during native startup. Studio
startup has a separate bounded allowance. PASS only describes these assertions at
this checkpoint, not the entire session or all game behavior.

## Smoke plans

Select join, spawn and/or latejoin, set their timeouts and run the selected plan.
Each case starts a separate native Studio multiplayer test. Join checks one joined
server player. Spawn also checks a character with Humanoid. Latejoin checks that
the initial player remains and one new player joins, making two. These checks do
not establish that LocalScripts, UI, character controls or the whole game are ready.
Smoke stores up to ten local reports and one local preset.

## Results and export

Results show PASS/FAIL, expected value, actual value and a concrete reason. Baseline
comparison also shows the old observation. A range remains a tolerance rather than
an exact comparison to its previous sample. **SAVED REPORT — previous run** is
historical evidence, not a new execution and cannot capture a fresh baseline.

Scroll to **Select JSON for export**, click it, press Ctrl+C, paste into your text
editor and save as a local `.json` file. No file-write or clipboard API is required.
Plugin settings are local to Studio and may be lost when the plugin/account/profile
is removed. Export is the portable backup; importing arbitrary JSON plans is not
included. Individual stored Snapshot envelopes are capped at 128 KiB.

## Cancellation and recovery

**Cancel results (server still finishes)** discards results. It does not forcibly
terminate Studio's native session. Wait for native completion, or use Studio's
**End Session** yourself when immediate termination is necessary. The plugin keeps
shared ownership across Snapshot and Smoke, preventing another native launch while
the previous call is pending. Invalid or ambiguous native returns keep Run blocked
until Studio is restarted. Follow the displayed recovery message; do not repeatedly
launch more clients. Close unrelated Studio editors to conserve RAM.

If a checkpoint times out, inspect character loading and Output, let the session
finish, correct your disposable copy and retry. A cancelled, failed or malformed
report never becomes a successful baseline.

## Remove or update safely

In edit mode with no active test, **Setup > Remove owned runner — Undo available**
detaches only the exact owned, versioned, unmodified runner. It preserves your game
objects and data. Undo restores the same instance. Remove the runner before shipping
your game. It is designed to return immediately outside explicitly marked Studio
server tests; a published runtime has not been validated by publishing a game.

Before updating the local plugin, use the **old matching plugin's Remove action**,
then replace the plugin, restart Studio and install the new runner. Unknown versions,
edited code, children and name collisions are preserved and refused. Inspect them
manually; do not delete content merely because it shares the runner's name. Disable
or uninstall the plugin itself through Studio's plugin management after removing
the runner. Uninstalling the plugin alone does not remove a script from your place.

## Privacy and support

The product uses local settings and Studio APIs. It has no AI API, telemetry,
remote HTTP endpoint, subscription, custom payment system or remote code dependency.
Ordinary Roblox Studio networking for its own native tests remains necessary.

For a reproducible bug report, provide plugin/Studio versions, the displayed error,
a minimal disposable place and an exported report. Remove private game data first.
Do not send credentials, personal account information or production player data.
