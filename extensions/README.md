# Fleet osquery extensions

Go-based osquery extensions for Fleet. Each adds a virtual table osquery cannot provide natively. One subdirectory per extension; drop a new one alongside and the build workflow picks it up.

Pattern and layout follow [`allenhouchins/fleet-extensions`](https://github.com/allenhouchins/fleet-extensions).

| Extension | Platform | Table | Binaries | Description |
|---|---|---|---|---|
| [windows_yellowkey](windows_yellowkey/) | Windows | `windows_yellowkey` | `windows_yellowkey-amd64.exe`, `windows_yellowkey-arm64.exe` | Per-host verdict for the YellowKey BitLocker bypass (CVE-2026-45585) |

## Build

Requires Go 1.21+. From an extension directory:

```
make deps
make build
```

Cross-compiles the Windows binaries (amd64 + arm64) from any host platform. `.github/workflows/build-extensions.yml` builds every extension on push to `main` and on PRs, and publishes release assets on a tag push.

## Use

Load an extension into Fleet's orbit for a quick test:

```
'C:\Program Files\Orbit\bin\orbit\orbit.exe' shell -- --extension .\windows_yellowkey-amd64.exe --allow-unsafe
```

Then query its table, for example `SELECT * FROM windows_yellowkey`. For fleet-wide deployment see the extension's own README.

## Layout

```
extensions/
└── windows_yellowkey/
    ├── main.go           # extension source
    ├── go.mod / go.sum   # module
    ├── Makefile          # cross-compile (make deps, make build)
    ├── README.md         # table schema, build, deploy
    └── *.exe             # committed prebuilt binaries
```

## Adding an extension

1. Create `extensions/<name>/` with `main.go`, `go.mod`, a `Makefile` with the same targets, and a `README.md`.
2. Register the table with the same name as the directory.
3. `make deps && make build`, then commit the binaries.
4. Add a row to the table above.
