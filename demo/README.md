# Regression Arena demonstration

`RegressionArena-Demo.rbxlx` was saved from Roblox Studio. It contains a Baseplate,
primitive door/frame/contract-board geometry and demonstration Attributes. It has
no Scripts, LocalScripts, ModuleScripts or preinstalled runner.

Open a disposable copy in Studio, install the production plugin, then follow the
[buyer guide](../release/BUYER_GUIDE.md#five-minute-demonstration). The bundled
Snapshot plan is loaded through the plugin; loading definitions does not insert
game objects. Reward may be 12 while the permitted range is 5–15.

Introduce the intentional bug in edit mode: `Workspace.RA_Demo.Door.CanCollide =
false`, Unlocked = false, Mode = `Closed`. The real Studio evidence records these
failures and a restored PASS, including a numeric change within the allowed range.
The demonstration is a data-contract example, not an interactive door system.

`tests/studio/BuildDemo.luau` is a developer authoring helper. It is not included in
the production plugin or buyer ZIP. The existing recovery Baseplates were not used
as distribution files or overwritten.
