# L-1: Linux device ID: Duo Desktop, Fleet and the CSV agree

- **Started:** 2026-10-07T18:49:07Z
- **Objective:** The ID Duo matches for a Linux host is its product UUID, which equals Fleet's host UUID and the row in linux.csv.
- **Expected:** Same value in all four places; Duo marks the endpoint trusted.

## Steps and evidence
- `01-on-the-host.txt` (VM): `echo "product_uuid: $(cat /sys/class/dmi/id/product_uuid)"; echo "machine-id : $(cat /etc/machine-id)  (the fa`
- `02-in-fleet-and-in-the-csv.txt`: `echo "Fleet host uuid : $(fleetctl api '/hosts/identifier/86d7dc8e-3373-47af-86dd-56a1cd517e2f' 2>/dev/null | `

Duo's side: the D-5 Auth Response (screenshots 06 to 07 in the D-5 folder) shows device_info_source duo_desktop and trusted_endpoint_status trusted for this host. Duo's admin endpoint record (Trusted Endpoint: Yes, via device health) was read earlier from the Admin Panel; a fresh capture needs the admin to sign in again.

## Result: **PASS**

product_uuid = Fleet host UUID = linux.csv row = 86d7dc8e-3373-47af-86dd-56a1cd517e2f, and Duo marked the endpoint trusted. Case matched (lowercase). The /etc/machine-id fallback is not used because this VM exposes a product UUID. L-2 (a VM without one) was not tested.

_Finished 2026-10-07T18:49:11Z_
