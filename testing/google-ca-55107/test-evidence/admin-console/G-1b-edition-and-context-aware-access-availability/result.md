# G-1b: edition and Context-Aware Access availability

- **Date:** 2026-10-09
- **Objective:** Find out if the guide's feature exists on the org
- **Expected:** Context-Aware Access page present on a supported edition

## Steps and evidence
- `01-...no-context-aware-access.png`: on **Business Plus** (default trial) the Security > Access and data control menu has no Context-Aware Access.
- `02-upgrade-options.png`: upgrade page (Business Plus, Enterprise Standard, Enterprise Plus).
- `03-...after-upgrade.png`: after upgrading to **Enterprise Standard**, Security > Context-Aware Access is "ON for everyone".

## Result: PASS

Guide findings: (1) Business Plus orgs don't have the page; state the supported editions. (2) For about an hour after the upgrade the page was not listed in the Security menu, but loaded at its path (`/ac/security/context-aware`).
