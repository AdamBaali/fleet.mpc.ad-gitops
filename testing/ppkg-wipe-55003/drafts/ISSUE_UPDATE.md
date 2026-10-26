# Draft comment for the issue (not posted; Adam reviews)

Lab results on Windows 11 26H2 with the provisioning package guide, a fleet that requires end user authentication, and
`doWipePersistProvisionedData`:

- **Bypass build:** enrolls during setup with no prompt, about 30 s after the package applies. MDM is on before any user exists.
- **Without bypass:** Fleet holds enrollment until the user signs in. On 26H2, Edge opens during setup, so the user signs in
  to the IdP right there and the host enrolls with that user linked, still before any account exists. So "fleetd won't
  communicate back until the end user authenticates" is true, and the sign-in can happen on the setup screen.
- **`doWipePersistProvisionedData`:** wipes the user and keeps the package, both the one applied at setup
  (`ProgramData\Microsoft\Provisioning`) and one staged later by a Fleet script in `C:\Recovery\Customizations`. The reset
  processed the staged one. So Fleet can set this up for hosts enrolled another way, as Omnissa does for Workspace ONE.
- **Not shown yet:** the host coming back to Fleet after the reset. Our arm64 VMs can't boot Windows after a reset (a
  hypervisor limit), so that last step needs a physical x64 laptop. Next run.

Doc fixes found on the way: the guide's "no browser during setup" note, the MDM-after-sign-in note, the bypass setting
in the setup experience guide (says `false`, should be `true`), and the Windows command library payloads (Fleet only
accepts the bare `<Exec>`).
