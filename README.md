# fleet.mpc.ad GitOps

GitOps configuration for the lab Fleet at `https://fleet.mpc.ad`, plus the testing that goes with it.
A push to `main` applies the configuration to Fleet (`.github/workflows/workflow.yml`).

## Layout
| Path | What it is |
| --- | --- |
| `default.yml` | Global settings: org settings, certificate authorities, global policies and reports |
| `fleets/<name>.yml` | One file per fleet: its policies, reports, software, settings and enroll secret |
| `fleets/<name>/` | That fleet's own documentation and helper files (not read by GitOps) |
| `lib/<platform>/...` | Shared building blocks the fleet files point to: policies, reports, scripts, profiles, software |
| `testing/<project>/` | One folder per test project: plan, results, generated `EVIDENCE.md`, raw evidence, lab setup |
| `testing/_framework/` | The reusable testing method: templates, helpers, the evidence index builder |
| `extensions/` | The Windows YellowKey osquery extension source |
| `.github/workflows/` | `workflow.yml` applies the configuration. `duo-sync*.yml` sync Fleet hosts to Duo for the Ping Duo Lab |

## Fleets
| Fleet | Purpose | Config | Docs |
| --- | --- | --- | --- |
| Ping Duo Lab | Test the PingFederate and Duo guides (#54654) | `fleets/ping-duo-lab.yml` | `fleets/ping-duo-lab/`, `testing/conditional-access-54654/` |
| Flock to Fedora | Linux atomic, OpenClaw and Windows YellowKey assets | `fleets/flock-to-fedora.yml` | `fleets/flock-to-fedora/CONTEXT.md` |
| Linux LUKS Lab | Test Linux disk encryption behavior (#54871) | `fleets/linux-luks-lab.yml` | `testing/` project for #54871 |

## Adding a fleet or a test
1. **Fleet:** add `fleets/<name>.yml` (the `name:` must be unique), put shared files under `lib/`, and add
   `fleets/<name>/README.md` with the purpose, owner and issue link.
2. **Test project:** copy `testing/_framework/templates/` into `testing/<project>/`, run the tests with
   `testing/_framework/bin/ev.sh`, and build `EVIDENCE.md` with `build-evidence-index.py`.
3. Pushes that only touch `testing/`, `fleets/<name>/` or markdown don't start a live apply.

## Rules
Secrets live in GitHub repository secrets and are referenced as `$FLEET_*` variables. Nothing secret is committed.
