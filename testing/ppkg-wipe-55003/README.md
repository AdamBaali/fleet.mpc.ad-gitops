# Reset a Windows host with a provisioning package (fleetdm/fleet#55003)

Tests whether a Windows host set up with Fleet's provisioning package guide comes back to Windows setup with fleetd
installed after `doWipePersistProvisionedData`, and what the end user sees when the fleet requires end user
authentication, with and without `--bypass-end-user-auth`. Input for the design review on Windows wipe for
repurposing. Method: `../_framework`.

Status (2026-10-27): done. The reset works with both builds and on brownfield hosts; the findings for the design are
in [RESULTS.md](RESULTS.md).

| File or folder | What it is |
| --- | --- |
| [TEST_PLAN.md](TEST_PLAN.md) | The plan: setup, enrollment, core flow, edge cases, UI, API, permissions |
| [RESULTS.md](RESULTS.md) | Results per test, answers, and findings |
| [EVIDENCE.md](EVIDENCE.md) | Generated index of every test with its screenshots and outputs |
| [NOTES.md](NOTES.md) | Desk findings from Fleet code and Microsoft docs; lab versus production |
| [IDP_SETUP.md](IDP_SETUP.md) | The mock IdP on the Mac for end user authentication |
| [HANDOFF.md](HANDOFF.md) | What is running and how to tear it down |
| `drafts/` | The draft issue comment. Not posted |
| `test-evidence/` | One folder per test. `archive/` keeps superseded attempts out of the index |
| `scripts/` | `stage-ppkg.ps1`, the Fleet script that stages the package in `C:\Recovery\Customizations` |
| `payloads/` | Wipe command payloads for `fleetctl mdm run-command`, and lab-only PowerShell |
| `queries/` | Live queries that check a host after a reset |
| `ppkg/` | ICD customization files for the packages |
| `idp/` | The mock IdP: container, Fleet as service provider, setup script, metadata |
| `tools/` | Lab scripts. The QEMU ones link to `../_framework/vm/` |
| `vm/` | Golden image build (UTM, used once to install Windows) |
| `private/` | Package passwords, IdP key and test user passwords, the enroll secret. Git ignores it |
