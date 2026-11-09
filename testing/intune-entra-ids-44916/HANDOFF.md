# Handoff: Intune and Entra device IDs

## State
- Research done ([NOTES.md](NOTES.md)). Candidate SQL in `queries/`, not run anywhere.
- No lab changes yet. No fleet declared for this project.
- T-4 and T-5 are blocked: no Entra or Intune tenant.

## Next steps
1. Add a `fleetctl` context for the lab Fleet. The current default context points at a different, non-lab Fleet. Don't use it for this project.
2. Declare a lab fleet for this project in `fleets/` with both reports, through a PR.
3. Run T-1 to T-3 on a lab Windows VM. Commit evidence after each test.
4. Get T-4 run on a real host: ask the customer to run both queries in their stage Fleet and compare with `dsregcmd /status` and the Intune portal, or ask the engineer who built the #44917 IdP vitals work, who tested on an Entra-joined device.
5. Raise with product: expose the Entra ID Fleet already collects on `GET /hosts/:id`.

## Running services (keep them on)
None.

## Teardown
- Fake registry keys and test certificates from T-1 and T-2 on the VM.
- The lab fleet and its reports, once done.

## Rules learned
- Check which `fleetctl` context is active before any command.
