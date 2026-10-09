# G-8: access level and apps list

- **Date:** 2026-10-09
- **Objective:** Create the access level with the guide's condition and see what it can protect
- **Expected:** Level saved, apps list visible

## Steps and evidence
- `01`/`02`: access level **Fleet managed iOS** created in **Advanced** mode with the condition `device.vendors["<customer-ID>-fleet"].is_managed_device == true`. Google accepted the CEL.
- `03`/`04`: Assign access levels: 20 apps (Admin Console, Calendar, Chrome Remote Desktop, Classroom, Cloud Search, Data Studio, Drive and Docs, Gemini Enterprise, Gemini Notebook, Gemini app, Gmail, Google Chat, Google Meet, Google Play Console, Google Vault, Groups for Business, Keep, Sites, Tasks, Workspace Studio). All Continuous evaluation.

## Result: PASS

The assignment to Drive and Gmail was done by the admin by hand. Screenshot 03 shows "1 active applied" at the top-level org for Admin Console, Drive and Gmail (lockout risk), still to confirm at the OU level. The customer ID in the condition may need the leading "C" removed (E-14).
Findings: a new assignment starts in monitor mode and blocks nothing until set Active.

Update (live test): the assignment was at the top-level OU for Admin Console, Drive and Gmail (lockout risk). Moved to the test OU only (Drive and Gmail, Active, apply to desktop and mobile apps). Whether the condition can be satisfied is C-1c.
