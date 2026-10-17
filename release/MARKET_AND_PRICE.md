# Pricing research — 2026-10-17

Recommendation for owner approval: **USD 19.99 once**, conditional on passing the
technical release gate. No price has been set publicly. This is a positioning
hypothesis, not a forecast of demand or sales.

| Alternative | Evidence from its publisher | Position relative to Regression Arena |
| --- | --- | --- |
| Avant Plugin, successor to Nexus Unit Testing | [Author's paid page](https://thenexusavenger.itch.io/avant-plugin) displayed a $200 minimum on this date; [source](https://github.com/Avant-Rbx/Avant-Plugin) is MIT and has a dismissible purchase reminder | Direct automated-testing plugin competitor. Graphical TestEZ execution, output and rerun selection. Its paid price is an itch.io observation, not a verified Creator Store price. Regression Arena's small declarative server-state workflow is different and narrower than a general code-test suite. |
| TestEZ | [Roblox's documentation](https://roblox.github.io/testez/) and [source](https://github.com/Roblox/testez) | Free/open-source assertion framework; strong substitute for developers willing to write test code. Regression Arena charges for a bounded authoring/baseline workflow, not unique access to testing. |
| TestEZ Companion | [Publisher repository](https://github.com/tacheometry/testez-companion) and [extension listing](https://marketplace.visualstudio.com/items?itemName=tacheometrist.testez-companion) | Open-source VS Code workflow for TestEZ results, with Studio plugin and Rojo setup. A close workflow substitute for teams already using external tooling. |
| Built-in Studio local server and TestService | [Roblox TestService reference](https://create.roblox.com/docs/reference/engine/classes/TestService), [StudioTestService](https://create.roblox.com/docs/reference/engine/classes/StudioTestService) | Included with Studio. Users can implement their own checks. Regression Arena adds saved explicit checks, validated evidence and baseline comparisons. |

The initial $39.99 hypothesis is not justified by evidence of buyer willingness to
pay. Version 1.0 supports one initial player, 16 assertions and one local baseline
slot, with manual JSON export and no headless CI integration. $19.99 keeps a paid
position while acknowledging these limits and credible free substitutes. Avant's
$200 paid build does not establish that a narrower product can command that price.

No competitor was purchased or installed, and no performance, sales or comparative
reliability claims are inferred from marketing pages. A search did not establish an
exhaustive inventory of all Creator Store competitors or a price for every listing.
The Avant DevForum page required browser verification; its author page and repository
provide the evidence used here.

Revisit price after voluntary buyer feedback and support experience, without adding
telemetry. Do not promise a future price increase or use invented scarcity. At launch
the product needs no paid hosting, AI service or recurring infrastructure. Roblox/
Stripe taxes, processing, refunds and developer support time still affect net income.

[Official Creator Store rules](https://create.roblox.com/docs/production/creator-store)
currently allow plugin prices from $4.99 to $249.99 and require a valid seller account.
The final owner must recheck policy and seller status before approving publication.
