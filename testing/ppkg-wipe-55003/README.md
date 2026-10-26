# Reset a Windows host with a provisioning package (fleetdm/fleet#55003)

Tests whether a Windows host set up with Fleet's provisioning package guide comes back to the first setup screen with
fleetd installed after an MDM wipe, and what the end user sees when the fleet requires end user authentication, with
and without `--bypass-end-user-auth`. Input for the design review on Windows wipe for repurposing. Same method as
`../_framework`.

Status (2026-10-26): planned. Nothing run. No lab changes yet.

| File or folder | What it is |
| --- | --- |
| [TEST_PLAN.md](TEST_PLAN.md) | The tests and how they pass |
| [IDP_SETUP.md](IDP_SETUP.md) | The lab IdP (Okta Integrator Free) for end user authentication |
| [NOTES.md](NOTES.md) | Desk findings from Fleet code and Microsoft docs, risks, lab versus production |
| [HANDOFF.md](HANDOFF.md) | State, next steps, teardown |
| `payloads/` | Wipe command payloads (to add in S-5) |
| `test-evidence/` | One folder per test (created when tests run) |
| `private/` | Package passwords, IdP org and user details. Git ignores it |
