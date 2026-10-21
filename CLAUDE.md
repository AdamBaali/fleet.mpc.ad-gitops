See README.md for how this repository is organized, and testing/_framework/README.md for the testing method.

Writing style for docs and comments: short, declarative sentences in the active voice. Sentence case headings. No em dashes.
No filler words (very, really, actually, basically, just, powerful, seamless). Say "hosts", not "endpoints" or "agents".
Comments explain why a choice was made, not what the code does. Never commit secrets.

This repository is public:
- No customer or person names in committed files. Use the customer's GitHub label. Internal links go in `testing/<project>/private/`, which git ignores.
- PR titles, PR descriptions, and commit messages never cite fleetdm/fleet issues (no `fleetdm/fleet#123`, no issue links). Files may.
- Work on a branch and merge through a pull request. A push to `main` applies to the lab Fleet.
- Verify before stating: read issues in full, check code at the customer's release tag, and test anything a customer will run.
