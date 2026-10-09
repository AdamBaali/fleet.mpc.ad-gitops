# S-1: Ubuntu 24.04.5 desktop installer, "Use LVM and encryption"

- **Date:** 2026-10-08
- **Objective:** Install Ubuntu the way the end user guide says (step 1), in a UTM VM, with a window screenshot of each page.
- **Expected:** An encrypted LVM install with a passphrase chosen at the installer.

## Steps and evidence
- `01`-`03`, `05`-`07`: language, accessibility, keyboard, an offered installer update (skipped), Try or install (Install Ubuntu).
- `12`: **How do you want to install Ubuntu?** with **Advanced features...** (the page the guide's screenshot shows).
- `13`-`15`: Advanced features dialog: **Use LVM and encryption** selected and confirmed. The page then says "LVM and encryption selected".
- `16`: **Create a passphrase** page, which says "You will be prompted for your passphrase every time you turn on your computer." (Q1). The passphrase was typed by the admin, not shown here.
- `17`: Create your account page (fields not filled in this picture).
- `18`: **Review your choices**: "Disk encryption: LUKS (LVM)", partitions vda1 fat32 /boot/efi, vda2 ext4 /boot, vda3 created.
- `19`-`22`: installing, "Ubuntu 24.04.5 LTS is installed and ready to use", restart, "Please remove the installation medium".
- A picture taken while the passphrase was visible was deleted, not kept.

## Result: PASS

Deviations from the guide: the installer option is labelled "Use LVM and encryption" (the guide's text says "Use LVM with encryption"; its picture caption says "and"). An installer update was offered and skipped (not in the guide). The timezone page did not appear as a separate step.
