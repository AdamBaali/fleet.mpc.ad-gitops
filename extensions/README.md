# Fleet osquery extensions

Temporary mirror of the windows_yellowkey osquery extension. The canonical source moved upstream to [`allenhouchins/fleet-extensions/windows_yellowkey`](https://github.com/allenhouchins/fleet-extensions/tree/main/windows_yellowkey); Allen's CI rebuilds the binaries on every push to `main` and publishes them to the `latest` release.

`lib/windows/scripts/install-yellowkey-extension.ps1` pulls from upstream's `releases/latest/download`. The files here are a backup, not the deployment source. They will be removed once the upstream release has been observed in production for a release cycle.

| Extension | Platform | Table | Upstream |
|---|---|---|---|
| [windows_yellowkey](windows_yellowkey/) | Windows | `windows_yellowkey` | [`allenhouchins/fleet-extensions/windows_yellowkey`](https://github.com/allenhouchins/fleet-extensions/tree/main/windows_yellowkey) |
