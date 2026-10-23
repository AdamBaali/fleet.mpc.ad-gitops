# Draft reply: personal phones with Fleet, now and after Okta

Customer: `customer-mozartia`. Status: draft, not sent. Post as a reply in the customer's Slack thread from the BYOD call.
Placeholders: `<contact>` is the customer's IT contact. The text below uses Slack formatting (`*bold*`, `_italic_`, `•`).
Every claim is checked in [README.md](README.md).

---

Hi <contact>, thanks for walking through this with us on Thursday. Here's a written summary you can share with your security team.

*Short version*
• Android can start now. A work profile keeps work and personal apart, and it doesn't need an identity provider (IdP).
• iPhone works best with Account-driven User Enrollment. It needs two things first: an IdP connected to Fleet, and Managed Apple Accounts in Apple Business.
• After you move to Okta, Okta can require a managed phone and check its basic security settings. Those checks run in Okta, not in Fleet policies.

*1. What Fleet sees on a personal phone*
Personal phones keep their privacy. Fleet manages only the work side.
• *iPhone:* Fleet sees the work apps it installed, iOS version, model, device name, and storage. Fleet can't see photos, messages, call logs, browsing, location, personal apps, the serial number, or the phone number. Fleet can't lock or erase the phone. When a user unenrolls, iOS removes the work apps and work data and leaves everything else.
• *Android:* Fleet sees only the work profile. Removing the work profile removes work apps and data only.
• Optional on iPhone: a restrictions profile that stops copy-paste and "Open in" between work and personal apps. It applies to apps Fleet installs, so deliver work apps through Fleet.
Apple's overview: https://support.apple.com/guide/deployment/user-enrollment-and-mdm-dep23db2037d/web

*2. Android: start now*
1. Turn on Android MDM in Fleet (https://fleetdm.com/guides/android-mdm-setup).
2. Create a fleet for personal Android phones.
3. Users remove their current Google work profile, then enroll in Fleet from a link or QR code. Removing the old profile removes the work apps and data that came with it, so plan a short window for each user.
Guide: https://fleetdm.com/guides/android-byod-mdm-migration

*3. iPhone: what it needs*
Account-driven User Enrollment has three parts:
1. *An IdP in Fleet.* Users sign in to Fleet during enrollment. Fleet works with any SAML IdP, including Auth0. Set the SAML _Name ID_ to the user's email. Fleet uses that value as the user's Managed Apple Account, so it has to match exactly. (https://fleetdm.com/guides/setup-experience) You mentioned Auth0 hit limits when you tried it before. Tell us what blocked it, and we'll help work through it.
2. *Managed Apple Accounts.* Verify your email domain in Apple Business and create accounts for your users.
3. *Federation (optional).* It lets users sign in to their Managed Apple Account with their IdP password instead of a separate Apple password. Apple's federation for custom IdPs needs a feature called Shared Signals. Okta supports it, and we haven't found Auth0 documentation for it. Please check with your IAM team. Until Okta, users may need a separate Apple password.
Guide: https://fleetdm.com/guides/enroll-personal-byod-ios-ipad-hosts-with-managed-apple-account

*4. About the notices to users*
Apple notifies people when you start _Domain Capture_ in Apple Business. Verifying the domain doesn't send notices. Here's what users see:
• Anyone with a personal Apple Account on a work address gets an email and a device notice.
• They have 30 days to pick a new email or move the account to the company.
• If they do nothing, Apple gives the account a new temporary address. They keep the account, their data, and their purchases.
• Domain Capture can't be undone, so tell staff before you start it.
In a previous role, I ran this for roughly 18,000 users at a large enterprise. Telling people early kept support requests low.
Apple's details: https://support.apple.com/guide/business/capture-a-domain-axm512ce43c3/web

Two settings to check:
• In Apple Business, set _Allow Managed Apple Account on_ to _Any device_ or _Managed devices only_. _Supervised devices only_ blocks personal phones, because they're never supervised. We'll confirm _Managed devices only_ in our lab before you rely on it.
• In Fleet, keep _Allow only Apple Business enrollments_ off. When it's on, personal iPhones can't enroll.

We recommend one email domain for all users. Fleet has one IdP setting for all platforms, so a separate BYOD-only address can't be limited to iPhones. A separate domain is fine for a small pilot.

*5. Compliance after you move to Okta*
How it works:
• Fleet installs Okta Verify as a managed app with a secret key from Okta. Okta then marks the phone as managed, and your sign-in rules can require a managed phone. Guide: https://fleetdm.com/guides/configure-okta-management-attestation-for-mobile-devices
• Okta's device assurance checks the phone through Okta Verify. On iPhone, it checks the iOS version, the screen lock (passcode, Face ID, or Touch ID), and jailbreak. Android adds checks such as disk encryption and root detection. (https://help.okta.com/oie/en-us/content/topics/identity-engine/devices/device-assurance-add.htm)

Good to know:
• Fleet can block an Okta sign-in when a Fleet policy fails on macOS today. Phones use Okta's own checks instead.
• On iPhone, Okta marks the whole phone as managed, not only the work side. A personal app on the same phone can pass a "managed phone" rule. Pair the rule with per-app controls in your key apps. Android doesn't have this gap.
• Users who already have Okta Verify delete it, and Fleet reinstalls it as a managed app. Apple doesn't let MDM take over an app the user installed.
• Okta documents this for managed phones, not specifically for User Enrollment. We'll test it on a personal iPhone in our lab and share the results.
• On Android, Fleet doesn't yet support secrets in app configuration, so the Okta key is stored in Fleet as plain text.

*6. Moving from Auth0 to Okta*
Fleet links each personal phone to the user's Name ID. If Okta sends the same email as Auth0, the link stays. On cutover day:
1. Point Fleet's IdP setting to Okta.
2. Set up federation between Apple Business and Okta.
3. Check a few pilot phones.
We'll test this cutover in our lab first.

*7. Personal laptops*
Fleet supports Account-driven User Enrollment for iPhone and iPad today. Mac support is an open feature request, and we'll keep you posted.

*Suggested next steps*
1. Pilot Android work profiles with 5-10 users now.
2. Your IAM team checks whether Auth0 can set up federation with Apple Business, and whether Auth0 can be Fleet's IdP.
3. We test the Okta Verify and IdP cutover steps in our lab.
4. Pilot iPhone once the IdP and Managed Apple Accounts are in place.

Happy to join a call with your IAM or security team.
