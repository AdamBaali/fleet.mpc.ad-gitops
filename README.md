# mpc.ad Fleet GitOps

Fleet GitOps configuration for mpc.ad. Fleet applies `default.yml` and every file
in `fleets/` on each push. Reusable profiles, scripts, policies, reports, and
software live under `lib/`, organized by platform.

## ACME certificate testing with nanoca

This repo ships profiles that enroll an Apple device identity certificate from a
test ACME server. Anyone with this repo can apply them and watch a certificate
issue against the shared test CA at `cert.mpc.ad`.

### Why

Apple devices can request an identity certificate over ACME using managed device
attestation. We wanted to test Fleet's Apple ACME configuration profile flow
against a real ACME server before wiring it to anything production. nanoca is a
small ACME certificate authority with Apple attestation support, so we deployed
it as a standalone server and drive it from Fleet with two profiles.

### What

A nanoca ACME server runs at `https://cert.mpc.ad`. Its directory is
`https://cert.mpc.ad/acme/directory`. Two macOS configuration profiles drive the
flow:

| Profile | Payload | Purpose |
|---------|---------|---------|
| `lib/macos/configuration-profiles/nanoca-root-ca-trust.mobileconfig` | `com.apple.security.root` | Installs the nanoca root CA so the issued certificate chains validate. |
| `lib/macos/configuration-profiles/nanoca-acme.mobileconfig` | `com.apple.security.acme` | Requests an identity certificate. Hardware bound, Secure Enclave attestation, EC P-384. Sets the client identifier and subject common name to the host hardware serial via `$FLEET_VAR_HOST_HARDWARE_SERIAL`. |

`fleets/workstations.yml` applies both to the Workstations fleet under
`controls.macos_settings.custom_settings`. The profiles carry no secrets and
point at the public `cert.mpc.ad`, so they are safe to copy and share.

### How

Apply the GitOps config:

```bash
fleetctl gitops -f default.yml -f fleets/workstations.yml
```

Or upload either profile directly in Fleet under Controls, OS settings, Custom
settings.

When a Mac receives the profiles it trusts the root CA, then runs the ACME flow:
`new-account`, `new-order`, a `device-attest-01` challenge backed by Secure
Enclave attestation, then `finalize`. nanoca validates the Apple attestation and
issues the certificate.

Verify the root CA installed on the Mac:

```bash
security find-certificate -c "MPC Demo Root CA" /Library/Keychains/System.keychain
```

Confirm the ACME server is reachable:

```bash
curl -s https://cert.mpc.ad/acme/directory
```

A successful run issues a certificate like this. The common name is the host
serial and the issuer is the test CA:

```
subject=CN = <host serial>
issuer=CN = MPC Demo Root CA, O = Mountain Path Consulting, C = AD
Public-Key: (384 bit)
X509v3 Extended Key Usage: TLS Web Client Authentication
```

### Status and limitations

This is a proof of concept. Do not rely on it for production identity.

- The ACME server uses a null authorizer. Any device that passes Apple
  attestation gets a certificate. It is not linked to Apple Business Manager
  tokens yet, so membership in an ABM organization is not checked.
- The signing CA is a throwaway demo CA. Its private key is public. Treat every
  certificate it issues as untrusted outside this test.
- The server runs behind a TLS-terminating proxy. The wrapper honors
  `X-Forwarded-Proto` so the ACME URL check passes.

### Next steps

- Link the ACME server to an ABM token so issuance is gated on ABM membership.
- Replace the demo CA with a real CA held outside the repo.
