# RA-002 actual evidence — 2026-10-14

This is an incomplete independent **native Server & Clients, four-client** control in the same disposable unpublished Baseplate. The RA runner was removed before the start. No RA-002 plugin plan has yet run; the older [RA-001 JSON reports](../studio-evidence/README.md) remain separate.

- [UI start action](ui-actions.json): observed four-client configuration, start-click UTC and absent runner.
- [Configuration screenshot](native-4-config.png): actual native controls before launch; RA panel hidden.
- [Engine events](engine-events.txt): selected actual RA002_NATIVE Output/lifecycle lines, no raw log dump. Server observer began approximately 31.96 seconds after launch and initially saw 0 players/ready characters. Final connection counts remain UNVERIFIED.
- [Resource CSV](resources.csv): 22 baseline and 31 native-phase actual read-only Windows samples. Timing gaps include query/scheduling delays; no process/account identifiers are retained.
- [Calculated ranges](resource-summary.json): aggregate sample ranges. Derived StudioCPUPercent is unreliable (one reading 104.4%) and **not used** as CPU evidence; raw values are preserved. SystemCPUPercent readings are the independent Win32_Processor LoadPercentage metric.

Native phase: available RAM minimum **60 MiB** of 8127 MiB, system CPU maximum **93%**, six Studio processes, up to six reported unresponsive, Studio private committed memory maximum **9996 MiB**. Committed memory is not resident RAM. These symptoms occurred without the RA runner; they do not establish a specific root cause.

Computer Use failed activation, two window-list attempts, and one fresh request after reset. Native cleanup is not claimed. Human End Session/return to the local Baseplate's edit mode was requested. The two-client native control, three consecutive two-player RA plans and additional safe ST cases are pending UI recovery.

See [diagnosis, measurement limits, remaining steps and proposed support boundary](../RA-002_DIAGNOSTICS.md) and [exact offline test output](../RA-002_TEST_LOG.txt). The product distribution was not changed to hide the environment failure; no publication or merge occurred.
