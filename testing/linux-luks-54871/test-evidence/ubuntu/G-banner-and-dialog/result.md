# G: the real Fleet Desktop banner and the real passphrase dialog

- **Date:** 2026-10-16
- **Objective:** Capture what an end user actually sees: the "Create key" banner on My device, and the passphrase dialog orbit opens.
- **Expected:** Banner when Fleet needs a key; a passphrase prompt dialog after Create key.

## Steps and evidence
- `00-state-setup.txt`: a temporary key slot was added and Fleet's slot removed, so Fleet needs a new key.
- `01-fleet-status.txt`: Fleet's status polling (it took far longer than the first time to go to action required; it did after a refetch and the timed-out request).
- `02-real-passphrase-dialog-empty.png`: **the real dialog orbit opens (zenity)**: "Enter disk encryption passphrase", a hidden-text field, Cancel and OK. Nobody typed; the lab wrapper was removed for this step.
- `03-real-dialog-after-timeout-message.png`: after 60 s with no input: "Please visit Fleet Desktop > My device and click Create key".
- `04-my-device-page-banner.png`: **the real My device page** (Fleet Desktop's page, device token not shown, public IP and MAC masked): banner "Disk encryption: Create a new disk encryption key. This lets your organization help you unlock your device if you forget your passphrase." with a **Create key** button; Disk encryption shows On.

## Result: PASS

Findings for the docs:
- The dialog needs a visible, **unlocked** desktop. With the screen locked (GNOME locks after 5 min idle) or the first-run "Welcome to Ubuntu" window in front, the dialog opens but nobody sees it, and it times out after 60 s. Fleet shows no error for that.
- After a timed-out request, a new request returns **HTTP 409** (a request is in flight) for several minutes.
- The request is picked up by orbit minutes later (about 3 to 4 minutes in this lab).
