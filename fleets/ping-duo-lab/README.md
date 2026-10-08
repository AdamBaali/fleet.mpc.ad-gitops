# Ping Duo Lab

Fleet used to test the PingFederate and Duo conditional access guides ([#54654](https://github.com/fleetdm/fleet/issues/54654),
[PR #54346](https://github.com/fleetdm/fleet/pull/54346)).

- **Config:** `../ping-duo-lab.yml`. Shared policies, profiles and software come from `lib/`.
- **Duo sync:** `duo-sync/` holds the export script and Duo's sync script (keys come from environment variables).
  Run by `.github/workflows/duo-sync.yml` and `duo-sync-loop.yml`. Needs the `DUO_*` repository secrets.
- **Tests and evidence:** `testing/conditional-access-54654/` (start at `EVIDENCE.md`).
- **Certificate authorities:** `LAB_CA` (custom SCEP) is declared in `default.yml`.
