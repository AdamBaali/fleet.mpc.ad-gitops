# Lab IdP for Fleet end user authentication

A mock SAML IdP on the Mac, with fake users. It lets us see Fleet's sign-in page, the IdP login, and the user Fleet
links to the host, without a real IdP account.


## What it is

- Image `fleetdm/docker-idp` (SimpleSAMLphp), the IdP Fleet uses for local development (`docker-compose.yml` and
  `tools/saml/` in fleetdm/fleet).
- Our own signing key, not the one in the public image. Anyone can pull that key, so trusting it would let anyone sign
  in as any user.
- Two users, `eua-user-1@example.com` and `eua-user-2@example.com`. Passwords are random, in
  `private/idp/CREDENTIALS.txt`.
- Port 9080 on the Mac. The VM reaches it at `http://idp.ppkg.test:9080`. A hosts file line in the VM points that name at
  `192.168.64.1`, UTM's default shared network address for the Mac. A `.test` name, not the IP, so Claude may type the fake
  test passwords into it. Add the line at the region screen (Shift+F10) on every fresh VM and after every reset:
  `echo 192.168.64.1 idp.ppkg.test >> C:\Windows\System32\drivers\etc\hosts`

SAML is a browser redirect. Only the VM's browser has to reach the IdP. Fleet on Render can't reach the Mac, so Fleet
gets the metadata inline in `default.yml` instead of a URL.

| File | What it is |
|---|---|
| `idp/docker-compose.yml` | The container |
| `idp/sp-remote.php` | Fleet as the service provider: entity ID `fleet-mpc-ad-end-users`, callback `https://fleet.mpc.ad/api/v1/fleet/mdm/sso/callback`, Name ID = email |
| `idp/setup.sh` | Creates the key, certificate, and users in `private/idp/` |
| `idp/metadata.xml` | The IdP metadata Fleet trusts (public certificate only). Copied into `default.yml` |


## Run it

```bash
testing/ppkg-wipe-55003/idp/setup.sh
```
```bash
docker compose -f testing/ppkg-wipe-55003/idp/docker-compose.yml up -d
```

Run `setup.sh` only once. Running it again makes a new key, and then `idp/metadata.xml` and `default.yml` must be
updated and applied again. The container restarts with Docker Desktop.


## Checked (2026-10-26)

- The metadata served for host `idp.ppkg.test:9080` carries our certificate, not the image's (regenerated for that name the same evening).
- A test login as `eua-user-1` returns a signed response with Name ID `eua-user-1@example.com` (email format),
  audience `fleet-mpc-ad-end-users`, and destination Fleet's callback.
- Not checked yet: Fleet accepting the response. That happens in E-2b.


## What the end user should see (no bypass)

1. At the desktop, fleetd opens the default browser to Fleet's sign-in page.
2. Fleet redirects to `http://idp.ppkg.test:9080/simplesaml/...`. The user signs in as `eua-user-1`.
3. The IdP posts back to `/api/v1/fleet/mdm/sso/callback`. Fleet links the IdP account to the host's UUID.
4. fleetd enrolls. Host details show the user under **Device user**.


## Lab versus production

- A real IdP runs over HTTPS on the internet. This one is HTTP on the local network. Fleet doesn't care, since only the
  signed response matters.
- No MFA, no sign-in policies, no FastPass prompts.


## Teardown

`docker compose -f testing/ppkg-wipe-55003/idp/docker-compose.yml down`, delete `private/idp/`, remove
`mdm.end_user_authentication` from `default.yml`.
