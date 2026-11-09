-- Inspection only: how osquery renders the certificates in the machine's personal store.
SELECT common_name, subject, issuer, sha1, not_valid_after, store_location, store
FROM certificates
WHERE store_location = 'LocalMachine' AND store = 'Personal';
