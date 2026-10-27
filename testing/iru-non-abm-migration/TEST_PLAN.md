# Test plan: migrate Macs that aren't in Apple Business from Iru to Fleet

Environment: lab Fleet 4.93.0 (Premium, Apple MDM on), an Iru Endpoint trial tenant, macOS VMs on Apple silicon.
Method: `../_framework`.


## User story

As an IT admin moving from Iru (formerly Kandji) to Fleet, I want to move Macs that aren't in Apple Business to Fleet
without wiping them, with the shortest possible gap in MDM coverage and as little work for the end user as possible.

Macs that aren't in Apple Business can't use Apple's ADE migration (reassign in Apple Business, then a deadline or
`profiles renew`). They are enrolled by hand, so the old MDM has to be removed first and the end user installs Fleet's
enrollment profile.


## Approaches to compare

**A. Policy and script (the pattern already used at a customer, all manual, no Apple Business).**
1. Iru deploys Fleet's agent (fleetd `.pkg`) as a custom app. The Mac is in both: Iru MDM and Fleet's agent.
2. A Fleet policy checks for the Iru agent (`/usr/local/bin/kandji`). Its script automation runs the agent's unenroll
   command, which removes the Iru agent and its MDM profile.
3. The end user opens Fleet Desktop and turns on MDM from **My device** (downloads and approves Fleet's enrollment
   profile).

**B. Fleet's end user migration workflow (Fleet's documented path).**
1. As A.1.
2. Turn on `mdm.macos_migration` (mode `voluntary` or `forced`) with a webhook URL. Fleet shows "Migrate to Fleet" in
   Fleet Desktop to hosts manually enrolled in another MDM (`IsEligibleForManualMigration`,
   `server/fleet/hosts.go` at fleet-v4.93.0: macOS later than 14.0, not assigned to Fleet in Apple Business).
3. The end user selects **Migrate to Fleet**. Fleet calls the webhook; an automation deletes the device record in Iru,
   which makes the Iru agent remove its profiles and itself at its next check-in (every 15 minutes, per Iru's docs).
4. Fleet's dialog walks the end user through installing Fleet's enrollment profile.

**C. Admin deletes the device in Iru (Fleet's default workflow).** Delete the device record in Iru (UI, bulk, or API),
then the end user turns on MDM from **My device**. Simplest; the longest gap.


## Open questions to answer first

| ID | Question | How |
|---|---|---|
| Q-1 | What is the Iru agent's local unenroll command, and does it remove the MDM profile? The command used before was `/usr/local/bin/kandji unenroll`, noted as unconfirmed; it isn't in Iru's public docs | `kandji --help` on an Iru-enrolled Mac; Iru support |
| Q-2 | Does Iru reinstall its agent or re-push the profile after a local unenroll? Iru's docs say the agent is reinstalled if the Mac checks in over MDM but not through the agent for 7 days | Watch the device record in Iru for a day after Q-1 |
| Q-3 | Does Iru's API delete a device record, for the approach B webhook? | Iru API reference (api-docs.iru.com), test token |
| Q-4 | Is Iru's MDM profile removable by the end user on a manual enrollment? | Look in System Settings after enrollment |
| Q-5 | Do macOS VMs on Apple silicon enroll in both MDMs (manual, user-approved)? | L-1 |


## Lab readiness

| ID | Test | Pass when |
|---|---|---|
| L-1 | macOS VM (UTM, Apple virtualization) enrolls manually in Iru: user-approved, agent installed | Iru shows the device; `profiles status -type enrollment` shows Iru, not DEP |
| L-2 | Iru deploys Fleet's agent `.pkg` (built with `fleetctl package --type=pkg --fleet-desktop`) | Host in Fleet, MDM status "On (manual)" for another server, Fleet Desktop in the menu bar |


## Tests

Each test starts from a fresh VM enrolled manually in Iru with Iru's agent, a FileVault-on disk, a standard and an admin
user, and one Iru configuration profile and one Iru app installed.

| ID | Approach | Steps | Pass when |
|---|---|---|---|
| M-1 | A | Fleet policy `SELECT 1 FROM file WHERE path = '/usr/local/bin/kandji'` (pass when no row), script automation runs the Q-1 command; then the end user turns on MDM from **My device** | Iru agent and every Iru profile gone (`profiles list`); Fleet MDM "On (manual)"; no Iru check-in afterwards. Record the gap from unenroll to Fleet MDM on |
| M-2 | B, voluntary | Turn on the migration workflow with a webhook to a lab automation that deletes the Iru device record; end user selects **Migrate to Fleet** | Dialog shown; Iru removed within about 15 minutes; Fleet MDM on after the end user follows the dialog. Record each screen and the gap |
| M-3 | B, forced | As M-2 with mode `forced` | Fleet keeps prompting until migrated; record how often |
| M-4 | C | Delete the device record in the Iru UI; end user turns on MDM from **My device** | As M-1 |
| M-5 | Standard user | M-1 (or the approach we pick) signed in as a standard user | Record whether a standard user can approve Fleet's profile. Fleet's guide says the default and end user workflows need an admin |
| M-6 | FileVault | After M-1, turn on Fleet disk encryption | Fleet escrows a new key after the end user logs out or restarts; record the prompts. Export Iru's recovery key first |
| M-7 | What Iru leaves behind | After each test, list profiles, apps and Iru's files and launch daemons | Recorded. Iru's Apps and Books apps should go with the device record; custom apps may stay |
| M-8 | Offline Mac | Delete the Iru record (or run the script) while the VM is off, start it later | Record what happens on next boot |


## Fleet side to prepare

- A fleet for migrated Macs with the configuration from the Iru blueprint, so policies, profiles and software apply as
  soon as MDM turns on.
- `mdm.macos_migration` in `default.yml` for approach B (it applies to every fleet). A webhook receiver for the lab:
  a small script or Tines.
- Policy and script for approach A in `lib/macos/`.


## Not in scope

Macs in Apple Business (Apple's ADE migration with a deadline covers those), iPhones and iPads, Windows, and Iru
features without a Fleet equivalent (handled in the configuration mapping, not this plan).
