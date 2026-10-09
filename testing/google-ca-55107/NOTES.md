# Notes
- Google test org: Workspace on a lab domain, Enterprise Standard (trial period). Only the OU **Fleet iOS test** is used. Context-Aware Access is assigned there only.
- Gmail can't be activated without MX records on the primary domain, so the sign-in tests use Drive and the Google app.
- Admin console clicks through Claude in Chrome: typing into fields in the Admin console failed (another extension in the browser); the form-fill tool worked.
- Security grants (JSON key, domain-wide delegation, assigning access levels, repository secrets) were done by the admin by hand.
- Not done yet: the iPhone enrollment, live sync run, sign-in and block tests (C-1 to C-4), schedule test (G-12), partner ID test (E-14). See `RUNBOOK.md`.
- Evidence rules: no admin email, no customer ID, no passwords. Screenshots are window-only.
