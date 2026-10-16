<!-- Reply to the customer, for the CSM to send after the Manager of CSA decides (Fleet handbook process). Not sent. -->
Hi, here's where BitLocker PIN stands after testing on Fleet 4.93.0 this week:

- **Non-admin users without Fleet Desktop:** not supported today. Windows asks for an admin username and password to add a
  startup PIN, and nothing prompts the user. That's true even when the PIN is set to Required.
- **What works today:** IT can enforce and set the PIN, without the user and without Fleet Desktop. We tested a Fleet script
  that adds the PIN on an already-encrypted Windows 11 device (a test VM); Fleet then reports the disk as Verified, a Fleet policy
  shows which devices still lack a PIN, and Windows then lets the user change it with their current PIN, without an admin prompt (we
  checked the dialog and that wrong PINs are rejected; a full change wasn't completed in the lab). You'd decide how users get their initial PIN.
  The details: Fleet now accepts your own BitLocker profile (since 4.90, once Fleet turns
  on `mdm.enable_custom_disk_encryption` for your instance). With a profile that sets the PIN to Required and blocks the other
  startup methods, an admin can add the PIN in Manage BitLocker, and Fleet reports the disk as Verified with the recovery key
  escrowed. Let Fleet encrypt the disk first, then apply the profile. We can share the exact profile.
- **6-digit PIN:** yes, set in the same profile.
- **Lock after 3 failed attempts:** not possible for the startup PIN. Windows locks the TPM after 32 failed attempts. The only
  related setting, which we tested pushing from Fleet, keeps it at 32 and slows recovery (one attempt back every 2 hours instead
  of every 10 minutes). At startup, though, Windows already stops guessing: in our test, the 6th wrong PIN sent the device to
  the BitLocker recovery screen, which needs the recovery key (stored in Fleet). Inside Windows, a user who mistypes their current PIN a few times while changing it is blocked until IT
  resets it.
- **Non-admin users setting their own PIN:** Fleet 4.93 adds a PIN form on the My device page, which needs Fleet Desktop and the
  next fleetd release (1.62, not out yet). There's no date for a path without Fleet Desktop.
- **"Only USB" showing as a startup option:** we reproduced this in our lab. When Windows classifies a device as a tablet ("Slate"),
  it refuses any startup option that needs typing (PIN or password) unless the setting "Enable use of BitLocker authentication
  requiring preboot keyboard input on slates" is on; turning it on fixed it in our test. Some clamshell laptops report "Slate"
  too. Could you open System Information (`msinfo32`) on one affected laptop and tell us the **Platform Role** it shows, plus the
  laptop model? (Or run the attached Fleet script on affected hosts: it prints the platform role and model.) If it says Slate,
  we'll send you a one-setting custom profile that turns it on (tested through Fleet in our lab).
