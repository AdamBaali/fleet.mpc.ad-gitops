# Proposed doc edits (fleetdm/fleet#54871)

Fleet's style: short plain sentences, sentence case headings. For `articles/enforce-disk-encryption.md` (after "Escrow disk encryption key on Linux") and `articles/linux-disk-encryption-end-user.md`. Draft only. Evidence for each point is in `EVIDENCE.md`.

## 1. Add to "Escrow disk encryption key on Linux" (supported distros)

> Fleet supports key escrow on Ubuntu Linux, Kubuntu Linux, and Fedora Linux. Fleet doesn't support key escrow on Arch Linux or Arch-based distributions like Manjaro and CachyOS.

(Evidence D-1. Check the final list against fleetdm/fleet#55070 before publishing: the code also accepts Zorin.)

## 2. New section: "Lock out the end user while keeping IT access"

> LUKS lets you keep several passphrases for one disk. Fleet adds its own passphrase (the escrowed key) and leaves the end user's passphrase in place. If you remove the end user's passphrase, the end user can't unlock the disk. You can still unlock it with the escrowed key.
>
> To remove the end user's passphrase, find the key slot, then remove it with the escrowed key:
>
> 1. Run `sudo cryptsetup luksDump <device>` and note the end user's key slot number. Fleet's slot is the newest one.
> 2. Save the escrowed key from **Actions > Show disk encryption key** to a file that only root can read.
> 3. Run `sudo cryptsetup luksKillSlot <device> <slot> --key-file <file>`.
>
> After you remove the end user's passphrase:
>
> - The host asks for a passphrase on the console every time it starts. Only the escrowed key unlocks it. The host can't restart on its own (for example after an update or a power loss) until someone enters the key.
> - Fleet doesn't notice the change. The disk encryption status stays **Verified**.
> - A saved copy of the LUKS header (a backup made by an installer or backup tool) can restore the old passphrase.
> - If the disk also unlocks with a TPM or a key file, the end user isn't locked out.
> - Don't remove Fleet's key slot. Fleet then shows **Action required** and asks the end user to create a new key.

(Evidence K-1, K-3, K-4, K-5, K-6, K-7, K-9, K-11.)

## 3. Add to the "Encryption key changes" / escrow note

> Adding, changing, or removing a passphrase doesn't change the disk's encryption key or the data on the disk. The other passphrases keep working. Only re-encrypting the disk or formatting it creates a new key.

(Evidence M-2, M-5, S-6.)

## 4. Escrow timing (end user guide)

> After the end user selects **Create key**, it can take a few minutes for the new key to appear.

(Evidence S-4: about 3.5 to 4.5 minutes from the request to the new key slot.)
