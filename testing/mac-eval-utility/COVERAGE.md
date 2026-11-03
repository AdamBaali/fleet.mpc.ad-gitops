# MEU test coverage

Generated from Mac Evaluation Utility 4.8.1 by `tools/build-meu-reports.py`. Don't edit by hand.

MEU 4.8.1 runs 376 tests. The Fleet reports cover 344. The other 32 need data osquery can't read; the table says why.

| Category | MEU test ID | Test | Status | How |
| --- | --- | --- | --- | --- |
| Computer Information | `CI_assess-Computer_Name` | Computer Name | Covered | system_info.computer_name |
| Computer Information | `CI_assess-MacOS_Version_Number` | macOS Version Number | Covered | os_version |
| Computer Information | `CI_assess-Mac_Model` | Mac Model | Covered | system_info.hardware_model |
| Computer Information | `CI_assess-Biometrics` | Touch ID Security Status | Not covered | Touch ID enrollment comes from bioutil; no osquery table exposes it |
| Computer Information | `CI_assess-CoProcessor_Version` | Secure Enclave | Covered | os_version.arch, ibridge_info |
| DNS | `NI_assess-Public_DNS_Name` | Public DNS Domain | Covered | system_info.hostname (MEU runs /bin/hostname) |
| DNS | `NI_assess-Primary_Network_Name` | Primary Search Domain | Covered | dns_resolvers, first search domain |
| DNS | `NI_assess-Search_Domains` | Supplemental Match Domains | Covered | dns_resolvers search list. MEU also lists supplemental match domains, which osquery doesn't expose |
| DNS | `NI_assess-DNS_Servers` | DNS Servers | Covered | dns_resolvers nameservers |
| Local | `NI_assess-Private_IP_Address` | Private IP Address | Covered | interface_addresses on the default route interface |
| Local | `NI_assess-Network_Quality` | Apple Network Responsiveness | Not covered | networkQuality runs a load test; not suitable for osquery |
| Local | `NI_assess-Network_Service_Order` | Active Network Interfaces | Covered | interface_addresses: interfaces with an IPv4 address. MEU lists them in service order, which osquery doesn't expose |
| Local | `NI_assess-Public_IP_Address` | Public IP Address | Not covered | Fleet already records each host's public IP |
| Local | `NI_assess-Host_File_Status` | Host File Status | Covered | hash of /private/etc/hosts against MEU's default hash, plus the non-default etc_hosts entries |
| Local | `NI_assess-Proxy_Information` | Proxy Information | Covered | plist: proxy types turned on in SystemConfiguration preferences. MEU asks CFNetwork for the proxy used for https://www.apple.com |
| Local | `NI_assess-WiFi_Details` | Wi-Fi Details | Covered | wifi_status. The network name needs Location Services for osquery on recent macOS |
| Local | `CH_assess-Custom_Hosts` | Custom Hosts | Not covered | Add hosts with --extra-host when building the reports |
| Local | `CC_assess-Content_Caching_Server_Info` | Content Caching Servers | Not covered | AssetCacheLocatorUtil has no osquery equivalent |
| Bonjour | `BN_assess-AirPlay` | AirPlay | Not covered | Bonjour browsing (dns-sd) has no osquery equivalent |
| Bonjour | `BN_assess-Remote_Audio_Output` | Remote Audio Output | Not covered | Bonjour browsing (dns-sd) has no osquery equivalent |
| Bonjour | `BN_assess-AirDrop` | AirDrop | Not covered | Bonjour browsing (dns-sd) has no osquery equivalent |
| Bonjour | `BN_assess-Classroom` | Classroom | Not covered | Bonjour browsing (dns-sd) has no osquery equivalent |
| Bonjour | `BN_assess-Classroom_Sharing` | Classroom Sharing | Not covered | Bonjour browsing (dns-sd) has no osquery equivalent |
| Bonjour | `BN_assess-Internet_Printing_Protocol` | Internet Printing Protocol | Not covered | Bonjour browsing (dns-sd) has no osquery equivalent |
| Bonjour | `BN_assess-Secure_Internet_Printing_Protocol` | Secure Internet Printing Protocol | Not covered | Bonjour browsing (dns-sd) has no osquery equivalent |
| Apple Intelligence | `MM_assess-Writing_Tools_Configuration` | Writing Tools Configuration | Covered | managed_policies com.apple.applicationaccess / allowWritingTools |
| Apple Intelligence | `MM_assess-Image_Playground_Configuration` | Image Playground Configuration | Covered | managed_policies com.apple.applicationaccess / allowImagePlayground |
| Apple Intelligence | `MM_assess-Mail_Summary_Configuration` | Mail Summary Configuration | Covered | managed_policies com.apple.applicationaccess / allowMailSummary |
| Apple Intelligence | `MM_assess-IDE_Prohibit_On_Device_Model_Interaction_Configuration` | Code Completion Configuration | Covered | managed_policies com.apple.dt.Xcode / IDEProhibitOnDeviceModelInteraction |
| Apple Intelligence | `MM_assess-IDE_Prohibit_Remote_Model_Interaction_Configuration` | Swift Assist Configuration | Covered | managed_policies com.apple.dt.Xcode / IDEProhibitRemoteModelInteraction |
| Apple Intelligence | `MM_assess-Genmoji_Configuration` | Genmoji Configuration | Covered | managed_policies com.apple.applicationaccess / allowGenmoji |
| Apple Intelligence | `MM_assess-External_Intelligence_Integrations_Configuration` | External Intelligence Integrations Configuration | Covered | managed_policies com.apple.applicationaccess / allowExternalIntelligenceIntegrations |
| Apple Intelligence | `MM_assess-MM_assess-allowAssistant` | Allow Siri | Covered | managed_policies com.apple.applicationaccess / allowAssistant |
| Apple Intelligence | `MM_assess-MM_assess-allowSafariSummary` | Allow Summarization in Safari | Covered | managed_policies com.apple.applicationaccess / allowSafariSummary |
| Apple Intelligence | `MM_assess-MM_assess-allowMailSmartReplies` | Allow Mail Smart Replies | Covered | managed_policies com.apple.applicationaccess / allowMailSmartReplies |
| Apple Intelligence | `MM_assess-MM_assess-allowNotesTranscriptionSummary` | Allow Notes Transcription Summary | Covered | managed_policies com.apple.applicationaccess / allowNotesTranscriptionSummary |
| Apple Intelligence | `MM_assess-MM_assess-allowNotesTranscription` | Allow Transcription in Notes | Covered | managed_policies com.apple.applicationaccess / allowNotesTranscription |
| Apple Intelligence | `MM_assess-MM_assess-allowAppleIntelligenceReport` | Allow Apple Intelligence Reports | Covered | managed_policies com.apple.applicationaccess / allowAppleIntelligenceReport |
| Apple Intelligence | `MM_assess-MM_assess-allowedExternalIntelligenceWorkspaceIDs` | Allowed External Intelligence Workspace IDs | Covered | managed_policies com.apple.applicationaccess / allowedExternalIntelligenceWorkspaceIDs |
| Apple Intelligence | `MM_assess-External_Intelligence_Integrations_Sign_In_Configuration` | External Intelligence Integrations Sign In Configuration | Covered | managed_policies com.apple.applicationaccess / allowExternalIntelligenceIntegrationsSignIn |
| Management | `MM_assess-PPPCConfig` | Privacy Preferences Policy Control Management Status | Covered | plist: entries in the TCC MDM overrides file that PPPC profiles write |
| Management | `MM_assess-Organization_Name` | Organization Name | Covered | plist: the Automated Device Enrollment cloud configuration record (ADE hosts only) |
| Management | `MM_assess-MDM_Server_URL` | Device Management Service URL | Covered | mdm.server_url |
| Management | `MM_assess-MDM_External_Reachability` | Device Management Service External Reachability | Covered | curl GET of mdm.server_url; any HTTP status counts as reachable |
| Management | `MM_assess-Automated_Device_Enrollment` | Device Management Service Enrollment Type | Covered | mdm.installed_from_dep |
| Management | `MM_assess-MDM_Enrollment_Type` | Device Management Service Enrollment | Covered | mdm.enrolled and mdm.user_approved |
| Management | `MM_assess-MDM_UserChannel_Enabled` | Managed User Account | Not covered | Managed user channel state isn't exposed to osquery |
| Management | `MM_assess-Allow_USB_Restricted_Mode` | USB Restricted Mode | Covered | managed_policies com.apple.applicationaccess / allowUSBRestrictedMode |
| Management | `MM_assess-Allow_RSR_Installation` | Rapid Security Response Installation Status | Covered | managed_policies com.apple.applicationaccess / allowRapidSecurityResponseInstallation |
| Management | `MM_assess-Allow_RSR_Removal` | Rapid Security Response Removal Status | Covered | managed_policies com.apple.applicationaccess / allowRapidSecurityResponseRemoval |
| Management | `MM_assess-Allow_Universal_Control` | Universal Control | Covered | managed_policies com.apple.applicationaccess / allowUniversalControl |
| Management | `MM_assess-Allow_UI_Configuration_Profile_Installation` | UI Configuration Profile Installation | Covered | managed_policies com.apple.applicationaccess / allowUIConfigurationProfileInstallation |
| Management | `MM_assess-System_Preferences_Configuration` | System Settings Configuration (Deprecated) | Covered | managed_policies: any com.apple.systempreferences key |
| Management | `MM_assess-NetworkTimeConfiguration` | Network Time Server Configuration | Covered | file_lines: server lines in /private/etc/ntp.conf |
| Security | `MM_assess-Firewall_Configuration` | Firewall Configuration | Covered | managed_policies com.apple.security.firewall / EnableFirewall |
| Security | `MM_assess-Proxy_Configuration` | Proxy Configuration | Not covered | Proxy payloads don't land in managed preferences; NI_assess-Proxy_Information reports the proxies in use |
| Security | `MM_assess-Screen_Saver_Ask_For_Password_Configuration` | Screen Saver Ask For Password Configuration | Covered | managed_policies com.apple.screensaver / askForPasswordDelay |
| Security | `MM_assess-Secure_Boot` | Secure Boot Status | Covered | secureboot (Apple silicon description, Intel T2 secure_mode) |
| Security | `MM_assess-Bootstrap_Token` | Bootstrap Token | Not covered | Bootstrap token status comes from profiles status; no osquery table |
| Security | `MM_assess-Screen_Saver_Idle_Time_Configuration` | Screen Saver Idle Time Configuration | Covered | managed_policies com.apple.screensaver,com.apple.screensaver.user / idleTime |
| Security | `MM_assess-Secure_Token` | Secure Token | Covered | dscl AuthenticationAuthority for each local login user |
| Security | `MM_assess-Screen_Saver_Lock_Configuration` | Screen Saver Lock Configuration | Covered | managed_policies com.apple.screensaver / askForPassword |
| Security | `MM_assess-Bypass_Screen_Capture_Alert_Configuration` | Bypass Screen Capture Alert Configuration | Covered | managed_policies com.apple.applicationaccess / forceBypassScreenCaptureAlert |
| Security | `MM_assess-ICloud-Recovery-Key` | iCloud FileVault Recovery | Not covered | No osquery table exposes iCloud FileVault recovery |
| Security | `MM_assess-GateKeeper_Configuration` | Gatekeeper Configuration | Covered | managed_policies com.apple.systempolicy.control / EnableAssessment |
| Security | `MM_assess-Finder_Context_Menu_Configuration` | Gatekeeper Administrator Override | Covered | managed_policies com.apple.systempolicy.managed / DisableOverride |
| Security | `MM_assess-AuthDB_Mods` | Authorization Database Modifications | Covered | authdb system.login.screensaver; the macOS default rule is use-login-window-ui |
| Security | `MM_assess-Volume_Owner` | Volume Ownership | Not covered | Volume ownership comes from diskutil apfs listUsers; no osquery table |
| Security | `MM_assess-Root_User_Status` | Root User Status | Covered | dscl read /Users/root Password, the command MEU runs |
| Security | `MM_assess-SIP_Status` | System Integrity Protection Status | Covered | sip_config flag sip |
| Security | `MM_assess-File_Vault_Recovery_Key_Escrow_Configuration` | FileVault Key Escrow Configuration | Covered | managed_policies FDERecoveryKeyEscrow Location, or the escrow file /var/db/FileVaultPRK.dat |
| Security | `MM_assess-FileVault_Status` | FileVault Status | Covered | filevault_status |
| Security | `MM_assess-Auto_Login_Configuration` | Automatic Login Configuration | Covered | managed_policies com.apple.loginwindow / com.apple.login.mcx.DisableAutoLoginClient |
| Security | `MM_assess-Gatekeeper_Status` | Gatekeeper Status | Covered | gatekeeper.assessments_enabled |
| Security | `MM_assess-Biometrics_Allowed` | Touch ID Management Status | Covered | managed_policies com.apple.applicationaccess / allowFingerprintForUnlock |
| Security | `MM_assess-Biometric_Changes_Allowed` | Touch ID Modification Allowed Status | Covered | managed_policies com.apple.applicationaccess / allowFingerprintModification |
| Security | `MM_assess-iCloud_Private_Relay_Configuration` | iCloud Private Relay Configuration | Covered | managed_policies com.apple.applicationaccess / allowCloudPrivateRelay |
| Security | `MM_assess-Air_Play_Incoming_Requests_Configuration` | Allow AirPlay Incoming Requests Configuration | Covered | managed_policies com.apple.applicationaccess / allowAirPlayIncomingRequests |
| Security | `MM_assess-Guest_Account_Configuration` | Guest User Configuration | Covered | managed_policies com.apple.MCX / DisableGuestAccount |
| Security | `MM_assess-Media_Sharing_Modification_Configuration` | Media Sharing Configuration | Covered | managed_policies com.apple.applicationaccess / allowMediaSharingModification |
| Security | `MM_assess-iPhone_Mirroring_Configuration` | iPhone Mirroring Configuration | Covered | managed_policies com.apple.applicationaccess / allowiPhoneMirroring |
| Security | `MM_assess-User-Type` | Account Privileges | Covered | owner of /dev/console and membership of group 80 (admin) |
| Managed Software Updates | `MM_assess-Software_Update_Server_Pre_Release_Install` | Beta Software Configuration | Covered | managed_policies com.apple.SoftwareUpdate / AllowPreReleaseInstallation |
| Managed Software Updates | `MM_assess-Software_Update_Server_Automatic_Install_App_Updates` | Automatic App Update Installation | Covered | managed_policies com.apple.SoftwareUpdate / AutomaticallyInstallAppUpdates |
| Managed Software Updates | `MM_assess-Software_Update_Server_Automatic_Install_macOS_Updates` | Automatic macOS Update Installation | Covered | managed_policies com.apple.SoftwareUpdate / AutomaticallyInstallMacOSUpdates |
| Managed Software Updates | `MM_assess-Software_Update_Server_Automatic_Check_Enabled` | Automatic Check Status | Covered | managed_policies com.apple.SoftwareUpdate / AutomaticCheckEnabled |
| Managed Software Updates | `MM_assess-Software_Update_Server_Automatic_Download` | Automatic Download | Covered | managed_policies com.apple.SoftwareUpdate / AutomaticDownload |
| Managed Software Updates | `MM_assess-Software_Update_Server_Config_Data_Install` | Automatic System Data Files and Security Updates | Covered | managed_policies com.apple.SoftwareUpdate / ConfigDataInstall |
| Managed Software Updates | `MM_assess-Software_Update_Server_Critical_Update_Install` | Critical Update Installation | Covered | managed_policies com.apple.SoftwareUpdate / CriticalUpdateInstall |
| Managed Software Updates | `MM_assess-Software_Update_Server_Restrict_Software_Update_To_Admin` | Admin Only Software Updates | Covered | managed_policies com.apple.SoftwareUpdate / restrict-software-update-require-admin-to-install |
| Extensible Single Sign-on | `IDM_AD_assess-Kerberos_SSO_Extension_Realms` | Kerberos SSO Extension Realms | Not covered | Extensible SSO payloads don't land in managed preferences; app_sso_platform needs the extension ID and realm up front |
| Extensible Single Sign-on | `IDM_AD_assess-IsPSSOConfigured` | Platform SSO Configuration | Not covered | As above. A fleet that knows its Platform SSO extension can query app_sso_platform directly |
| Extensible Single Sign-on | `IDM_AD_assess-SSO_Extensions_Configured` | Configured SSO Extensions | Not covered | As above |
| Active Directory | `IDM_AD_assess-AD_Computer_Info` | Active Directory Binding | Covered | ad_config |
| Active Directory | `IDM_AD_assess-AD_DNS_Info` | Active Directory DNS Records | Not covered | Needs SRV lookups; osquery has no DNS query table |
| Active Directory | `IDM_AD_assess-AD_User_Info` | Active Directory User Info | Not covered | Mobile account detection isn't exposed to osquery |
| Smart Cards | `IDM_SC_assess-Attribute_Mapping_Type` | Attribute Mapping | Covered | file: /private/etc/SmartcardLogin.plist |
| Smart Cards | `IDM_SC_assess-Account_Pairing` | Account Pairing | Not covered | sc_auth identities has no osquery equivalent |
| Application Information | `KI_assess-KEXTs` | Third-Party KEXTs | Covered | kernel_extensions not named com.apple.* |
| Application Information | `AI_assess-Intel_Only_Apps` | Non-Universal Applications | Covered | signature architecture slices of each app in /Applications |
| Application Information | `AI_assess-Non_Notarized_Apps` | Non-Notarized Applications | Not covered | osquery's signature table doesn't report notarization |
| Application Information | `AI_assess-SHA1_Apps` | SHA1 Signed Applications | Not covered | Candidate: codesign.cdhash_sha256 is empty for SHA-1-only signatures. Needs testing on a host first |
| Application Information | `KI_assess-MDM_KEXTs` | Device Management Service Approved Third-Party KEXTs | Not covered | Kernel extension policy payloads don't land in managed preferences |
| Application Information | `AI_assess-Unsigned_Apps` | Unsigned Applications | Covered | signature of each app in /Applications |
| Application Information | `AI_assess-Agents` | Background Agents | Covered | startup_items type agent outside /System |
| Application Information | `AI_assess-Daemons` | Background Daemons | Covered | startup_items type daemon outside /System |
| Application Information | `AI_assess-LoginItems` | Login Items | Covered | startup_items that aren't agents or daemons |
| Application Information | `AI_assess-ConferencingApps` | Conferencing Application APIs | Not covered | Inspects app binaries for ScreenCaptureKit symbols; no osquery equivalent |
| Application Information | `SEI_assess-System_Extension_List` | Installed System Extensions | Covered | system_extensions |
| Push Notifications (Port 443) | `ANR_APNS_Courier_assess-1-courier.push.apple.com:443` | 1-courier.push.apple.com:443 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 443) | `ANR_APNS_Courier_assess-2-courier.push.apple.com:443` | 2-courier.push.apple.com:443 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 443) | `ANR_APNS_Courier_assess-3-courier.push.apple.com:443` | 3-courier.push.apple.com:443 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 443) | `ANR_APNS_Courier_assess-4-courier.push.apple.com:443` | 4-courier.push.apple.com:443 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 443) | `ANR_APNS_Courier_assess-5-courier.push.apple.com:443` | 5-courier.push.apple.com:443 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 443) | `ANR_APNS_Courier_assess-6-courier.push.apple.com:443` | 6-courier.push.apple.com:443 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 443) | `ANR_APNS_Courier_assess-7-courier.push.apple.com:443` | 7-courier.push.apple.com:443 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 443) | `ANR_APNS_Courier_assess-8-courier.push.apple.com:443` | 8-courier.push.apple.com:443 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 443) | `ANR_APNS_Courier_assess-9-courier.push.apple.com:443` | 9-courier.push.apple.com:443 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 443) | `ANR_APNS_Courier_assess-10-courier.push.apple.com:443` | 10-courier.push.apple.com:443 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 443) | `ANR_APNS_Courier_assess-11-courier.push.apple.com:443` | 11-courier.push.apple.com:443 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 443) | `ANR_APNS_Courier_assess-12-courier.push.apple.com:443` | 12-courier.push.apple.com:443 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 443) | `ANR_APNS_Courier_assess-13-courier.push.apple.com:443` | 13-courier.push.apple.com:443 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 443) | `ANR_APNS_Courier_assess-14-courier.push.apple.com:443` | 14-courier.push.apple.com:443 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 443) | `ANR_APNS_Courier_assess-15-courier.push.apple.com:443` | 15-courier.push.apple.com:443 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 443) | `ANR_APNS_Courier_assess-16-courier.push.apple.com:443` | 16-courier.push.apple.com:443 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 443) | `ANR_APNS_Courier_assess-17-courier.push.apple.com:443` | 17-courier.push.apple.com:443 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 443) | `ANR_APNS_Courier_assess-18-courier.push.apple.com:443` | 18-courier.push.apple.com:443 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 443) | `ANR_APNS_Courier_assess-19-courier.push.apple.com:443` | 19-courier.push.apple.com:443 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 443) | `ANR_APNS_Courier_assess-20-courier.push.apple.com:443` | 20-courier.push.apple.com:443 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 443) | `ANR_APNS_Courier_assess-21-courier.push.apple.com:443` | 21-courier.push.apple.com:443 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 443) | `ANR_APNS_Courier_assess-22-courier.push.apple.com:443` | 22-courier.push.apple.com:443 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 443) | `ANR_APNS_Courier_assess-23-courier.push.apple.com:443` | 23-courier.push.apple.com:443 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 443) | `ANR_APNS_Courier_assess-24-courier.push.apple.com:443` | 24-courier.push.apple.com:443 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 443) | `ANR_APNS_Courier_assess-25-courier.push.apple.com:443` | 25-courier.push.apple.com:443 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 443) | `ANR_APNS_Courier_assess-26-courier.push.apple.com:443` | 26-courier.push.apple.com:443 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 443) | `ANR_APNS_Courier_assess-27-courier.push.apple.com:443` | 27-courier.push.apple.com:443 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 443) | `ANR_APNS_Courier_assess-28-courier.push.apple.com:443` | 28-courier.push.apple.com:443 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 443) | `ANR_APNS_Courier_assess-29-courier.push.apple.com:443` | 29-courier.push.apple.com:443 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 443) | `ANR_APNS_Courier_assess-30-courier.push.apple.com:443` | 30-courier.push.apple.com:443 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 443) | `ANR_APNS_Courier_assess-31-courier.push.apple.com:443` | 31-courier.push.apple.com:443 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 443) | `ANR_APNS_Courier_assess-32-courier.push.apple.com:443` | 32-courier.push.apple.com:443 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 443) | `ANR_APNS_Courier_assess-33-courier.push.apple.com:443` | 33-courier.push.apple.com:443 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 443) | `ANR_APNS_Courier_assess-34-courier.push.apple.com:443` | 34-courier.push.apple.com:443 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 443) | `ANR_APNS_Courier_assess-35-courier.push.apple.com:443` | 35-courier.push.apple.com:443 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 443) | `ANR_APNS_Courier_assess-36-courier.push.apple.com:443` | 36-courier.push.apple.com:443 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 443) | `ANR_APNS_Courier_assess-37-courier.push.apple.com:443` | 37-courier.push.apple.com:443 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 443) | `ANR_APNS_Courier_assess-38-courier.push.apple.com:443` | 38-courier.push.apple.com:443 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 443) | `ANR_APNS_Courier_assess-39-courier.push.apple.com:443` | 39-courier.push.apple.com:443 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 443) | `ANR_APNS_Courier_assess-40-courier.push.apple.com:443` | 40-courier.push.apple.com:443 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 443) | `ANR_APNS_Courier_assess-41-courier.push.apple.com:443` | 41-courier.push.apple.com:443 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 443) | `ANR_APNS_Courier_assess-42-courier.push.apple.com:443` | 42-courier.push.apple.com:443 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 443) | `ANR_APNS_Courier_assess-43-courier.push.apple.com:443` | 43-courier.push.apple.com:443 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 443) | `ANR_APNS_Courier_assess-44-courier.push.apple.com:443` | 44-courier.push.apple.com:443 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 443) | `ANR_APNS_Courier_assess-45-courier.push.apple.com:443` | 45-courier.push.apple.com:443 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 443) | `ANR_APNS_Courier_assess-46-courier.push.apple.com:443` | 46-courier.push.apple.com:443 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 443) | `ANR_APNS_Courier_assess-47-courier.push.apple.com:443` | 47-courier.push.apple.com:443 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 443) | `ANR_APNS_Courier_assess-48-courier.push.apple.com:443` | 48-courier.push.apple.com:443 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 443) | `ANR_APNS_Courier_assess-49-courier.push.apple.com:443` | 49-courier.push.apple.com:443 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 443) | `ANR_APNS_Courier_assess-50-courier.push.apple.com:443` | 50-courier.push.apple.com:443 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 443) | `ANR_APNS_Courier_assess-us-courier.push.apple.com:443` | us-courier.push.apple.com:443 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 443) | `ANR_APNS_Courier_assess-courier.push.apple.com:443` | courier.push.apple.com:443 | Covered | curl_certificate issuer must be Apple Inc. |
| Push Notifications (Port 5223) | `ANR_APNS_Courier_assess-1-courier.push.apple.com:5223` | 1-courier.push.apple.com:5223 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 5223) | `ANR_APNS_Courier_assess-2-courier.push.apple.com:5223` | 2-courier.push.apple.com:5223 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 5223) | `ANR_APNS_Courier_assess-3-courier.push.apple.com:5223` | 3-courier.push.apple.com:5223 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 5223) | `ANR_APNS_Courier_assess-4-courier.push.apple.com:5223` | 4-courier.push.apple.com:5223 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 5223) | `ANR_APNS_Courier_assess-5-courier.push.apple.com:5223` | 5-courier.push.apple.com:5223 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 5223) | `ANR_APNS_Courier_assess-6-courier.push.apple.com:5223` | 6-courier.push.apple.com:5223 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 5223) | `ANR_APNS_Courier_assess-7-courier.push.apple.com:5223` | 7-courier.push.apple.com:5223 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 5223) | `ANR_APNS_Courier_assess-8-courier.push.apple.com:5223` | 8-courier.push.apple.com:5223 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 5223) | `ANR_APNS_Courier_assess-9-courier.push.apple.com:5223` | 9-courier.push.apple.com:5223 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 5223) | `ANR_APNS_Courier_assess-10-courier.push.apple.com:5223` | 10-courier.push.apple.com:5223 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 5223) | `ANR_APNS_Courier_assess-11-courier.push.apple.com:5223` | 11-courier.push.apple.com:5223 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 5223) | `ANR_APNS_Courier_assess-12-courier.push.apple.com:5223` | 12-courier.push.apple.com:5223 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 5223) | `ANR_APNS_Courier_assess-13-courier.push.apple.com:5223` | 13-courier.push.apple.com:5223 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 5223) | `ANR_APNS_Courier_assess-14-courier.push.apple.com:5223` | 14-courier.push.apple.com:5223 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 5223) | `ANR_APNS_Courier_assess-15-courier.push.apple.com:5223` | 15-courier.push.apple.com:5223 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 5223) | `ANR_APNS_Courier_assess-16-courier.push.apple.com:5223` | 16-courier.push.apple.com:5223 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 5223) | `ANR_APNS_Courier_assess-17-courier.push.apple.com:5223` | 17-courier.push.apple.com:5223 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 5223) | `ANR_APNS_Courier_assess-18-courier.push.apple.com:5223` | 18-courier.push.apple.com:5223 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 5223) | `ANR_APNS_Courier_assess-19-courier.push.apple.com:5223` | 19-courier.push.apple.com:5223 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 5223) | `ANR_APNS_Courier_assess-20-courier.push.apple.com:5223` | 20-courier.push.apple.com:5223 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 5223) | `ANR_APNS_Courier_assess-21-courier.push.apple.com:5223` | 21-courier.push.apple.com:5223 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 5223) | `ANR_APNS_Courier_assess-22-courier.push.apple.com:5223` | 22-courier.push.apple.com:5223 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 5223) | `ANR_APNS_Courier_assess-23-courier.push.apple.com:5223` | 23-courier.push.apple.com:5223 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 5223) | `ANR_APNS_Courier_assess-24-courier.push.apple.com:5223` | 24-courier.push.apple.com:5223 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 5223) | `ANR_APNS_Courier_assess-25-courier.push.apple.com:5223` | 25-courier.push.apple.com:5223 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 5223) | `ANR_APNS_Courier_assess-26-courier.push.apple.com:5223` | 26-courier.push.apple.com:5223 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 5223) | `ANR_APNS_Courier_assess-27-courier.push.apple.com:5223` | 27-courier.push.apple.com:5223 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 5223) | `ANR_APNS_Courier_assess-28-courier.push.apple.com:5223` | 28-courier.push.apple.com:5223 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 5223) | `ANR_APNS_Courier_assess-29-courier.push.apple.com:5223` | 29-courier.push.apple.com:5223 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 5223) | `ANR_APNS_Courier_assess-30-courier.push.apple.com:5223` | 30-courier.push.apple.com:5223 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 5223) | `ANR_APNS_Courier_assess-31-courier.push.apple.com:5223` | 31-courier.push.apple.com:5223 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 5223) | `ANR_APNS_Courier_assess-32-courier.push.apple.com:5223` | 32-courier.push.apple.com:5223 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 5223) | `ANR_APNS_Courier_assess-33-courier.push.apple.com:5223` | 33-courier.push.apple.com:5223 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 5223) | `ANR_APNS_Courier_assess-34-courier.push.apple.com:5223` | 34-courier.push.apple.com:5223 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 5223) | `ANR_APNS_Courier_assess-35-courier.push.apple.com:5223` | 35-courier.push.apple.com:5223 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 5223) | `ANR_APNS_Courier_assess-36-courier.push.apple.com:5223` | 36-courier.push.apple.com:5223 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 5223) | `ANR_APNS_Courier_assess-37-courier.push.apple.com:5223` | 37-courier.push.apple.com:5223 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 5223) | `ANR_APNS_Courier_assess-38-courier.push.apple.com:5223` | 38-courier.push.apple.com:5223 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 5223) | `ANR_APNS_Courier_assess-39-courier.push.apple.com:5223` | 39-courier.push.apple.com:5223 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 5223) | `ANR_APNS_Courier_assess-40-courier.push.apple.com:5223` | 40-courier.push.apple.com:5223 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 5223) | `ANR_APNS_Courier_assess-41-courier.push.apple.com:5223` | 41-courier.push.apple.com:5223 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 5223) | `ANR_APNS_Courier_assess-42-courier.push.apple.com:5223` | 42-courier.push.apple.com:5223 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 5223) | `ANR_APNS_Courier_assess-43-courier.push.apple.com:5223` | 43-courier.push.apple.com:5223 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 5223) | `ANR_APNS_Courier_assess-44-courier.push.apple.com:5223` | 44-courier.push.apple.com:5223 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 5223) | `ANR_APNS_Courier_assess-45-courier.push.apple.com:5223` | 45-courier.push.apple.com:5223 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 5223) | `ANR_APNS_Courier_assess-46-courier.push.apple.com:5223` | 46-courier.push.apple.com:5223 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 5223) | `ANR_APNS_Courier_assess-47-courier.push.apple.com:5223` | 47-courier.push.apple.com:5223 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 5223) | `ANR_APNS_Courier_assess-48-courier.push.apple.com:5223` | 48-courier.push.apple.com:5223 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 5223) | `ANR_APNS_Courier_assess-49-courier.push.apple.com:5223` | 49-courier.push.apple.com:5223 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 5223) | `ANR_APNS_Courier_assess-50-courier.push.apple.com:5223` | 50-courier.push.apple.com:5223 | Covered | curl_certificate TLS handshake |
| Push Notifications (Port 5223) | `ANR_APNS_Courier_assess-us-courier.push.apple.com:5223` | us-courier.push.apple.com:5223 | Covered | curl_certificate TLS handshake |
| Claris Connect | `NC_Claris_Servers_assess-wildcard-ocsp.rootca1.amazontrust.com:80` | ocsp.rootca1.amazontrust.com:80 | Covered | curl HTTP GET |
| Claris Connect | `NC_Claris_Servers_assess-wildcard-crt.rootca1.amazontrust.com:80` | crt.rootca1.amazontrust.com:80 | Covered | curl HTTP GET |
| Claris Connect | `NC_Claris_Servers_assess-wildcard-crl.rootca1.amazontrust.com:80` | crl.rootca1.amazontrust.com:80 | Covered | curl HTTP GET |
| Claris Connect | `NC_Claris_Servers_assess-crl.comodoca.com:80` | crl.comodoca.com:80 | Covered | curl HTTP GET |
| Claris Connect | `NC_Claris_Servers_assess-ocsp.comodoca.com:80` | ocsp.comodoca.com:80 | Covered | curl HTTP GET |
| Claris Connect | `NC_Claris_Servers_assess-ocsp.rootca1.amazontrust.com:80` | ocsp.rootca1.amazontrust.com:80 | Covered | curl HTTP GET; same host and port tested once |
| Claris Connect | `NC_Claris_Servers_assess-ocsp.rootca2.amazontrust.com:80` | ocsp.rootca2.amazontrust.com:80 | Covered | curl HTTP GET |
| Claris Connect | `NC_Claris_Servers_assess-ocsp.rootca3.amazontrust.com:80` | ocsp.rootca3.amazontrust.com:80 | Covered | curl HTTP GET |
| Claris Connect | `NC_Claris_Servers_assess-ocsp.rootca4.amazontrust.com:80` | ocsp.rootca4.amazontrust.com:80 | Covered | curl HTTP GET |
| Claris Connect | `NC_Claris_Servers_assess-ocsp.rootg2.amazontrust.com:80` | ocsp.rootg2.amazontrust.com:80 | Covered | curl HTTP GET |
| Claris Connect | `NC_Claris_Servers_assess-www.ifmcloud.com:443` | www.ifmcloud.com:443 | Covered | curl_certificate TLS handshake |
| Claris Connect | `NC_Claris_Servers_assess-my.claris.com:443` | my.claris.com:443 | Covered | curl_certificate TLS handshake |
| Claris Connect | `NC_Claris_Servers_assess-console.claris.com:443` | console.claris.com:443 | Covered | curl_certificate TLS handshake |
| Claris Connect | `NC_Claris_Servers_assess-api-global.ifmcloud.com:443` | api-global.ifmcloud.com:443 | Covered | curl_certificate TLS handshake |
| Claris Connect | `NC_Claris_Servers_assess-api-cp-global.ifmcloud.com:443` | api-cp-global.ifmcloud.com:443 | Covered | curl_certificate TLS handshake |
| Claris Connect | `NC_Claris_Servers_assess-connect.claris.com:443` | connect.claris.com:443 | Covered | curl_certificate TLS handshake |
| Device Setup | `NC_Time_Servers_assess-time-macos.apple.com:123` | time-macos.apple.com:123 | Not covered | NTP over UDP; osquery has no UDP probe |
| Device Setup | `NC_Time_Servers_assess-time-ios.apple.com:123` | time-ios.apple.com:123 | Not covered | NTP over UDP; osquery has no UDP probe |
| Device Setup | `NC_Time_Servers_assess-time.apple.com:123` | time.apple.com:123 | Not covered | NTP over UDP; osquery has no UDP probe |
| Device Setup | `NC_Device_Setup_assess-static.ips.apple.com:443` | static.ips.apple.com:443 | Covered | curl_certificate TLS handshake |
| Device Setup | `NC_Device_Setup_assess-captive.apple.com:443` | captive.apple.com:443 | Covered | curl_certificate TLS handshake |
| Device Setup | `NC_Device_Setup_assess-tbsc.apple.com:443` | tbsc.apple.com:443 | Covered | curl_certificate TLS handshake |
| Device Setup | `NC_Device_Setup_assess-humb.apple.com:443` | humb.apple.com:443 | Covered | curl_certificate TLS handshake |
| Device Setup | `NC_Device_Setup_assess_dup-gs.apple.com:443` | gs.apple.com:443 | Covered | curl_certificate TLS handshake |
| Device Setup | `NC_Device_Setup_assess-sq-device.apple.com:443` | sq-device.apple.com:443 | Covered | curl_certificate TLS handshake |
| Device Setup | `NC_Device_Setup_assess-albert.apple.com:443` | albert.apple.com:443 | Covered | curl_certificate TLS handshake |
| Device Management | `NC_MDM_Servers_assess-init-p01st.push.apple.com:80` | init-p01st.push.apple.com:80 | Covered | curl HTTP GET |
| Device Management | `NC_MDM_Servers_assess-init.push.apple.com:443` | init.push.apple.com:443 | Covered | curl_certificate TLS handshake |
| Device Management | `NC_MDM_Servers_assess-wildcard-api.push.apple.com:2197` | api.push.apple.com:2197 | Covered | curl_certificate TLS handshake |
| Device Management | `NC_MDM_Servers_assess-wildcard-1-courier.push.apple.com:5223` | 1-courier.push.apple.com:5223 | Covered | curl_certificate TLS handshake; same host and port tested once |
| Device Management | `NC_Device_Management_assess-vpp.itunes.apple.com:443` | vpp.itunes.apple.com:443 | Covered | curl_certificate TLS handshake |
| Device Management | `NC_Device_Management_assess-setup.icloud.com:443` | setup.icloud.com:443 | Covered | curl_certificate TLS handshake |
| Device Management | `NC_Device_Management_assess-axm-servicediscovery.apple.com:443` | axm-servicediscovery.apple.com:443 | Covered | curl_certificate TLS handshake |
| Device Management | `NC_Device_Management_assess-mdmenrollment.apple.com:443` | mdmenrollment.apple.com:443 | Covered | curl_certificate TLS handshake |
| Device Management | `NC_Device_Management_assess-iprofiles.apple.com:443` | iprofiles.apple.com:443 | Covered | curl_certificate TLS handshake |
| Device Management | `NC_Device_Management_assess-identity.apple.com:443` | identity.apple.com:443 | Covered | curl_certificate TLS handshake |
| Device Management | `NC_Device_Management_assess-gdmf.apple.com:443` | gdmf.apple.com:443 | Covered | curl_certificate TLS handshake |
| Device Management | `NC_Device_Management_assess-deviceservices-external.apple.com:443` | deviceservices-external.apple.com:443 | Covered | curl_certificate TLS handshake |
| Device Management | `NC_Device_Management_assess-deviceenrollment.apple.com:443` | deviceenrollment.apple.com:443 | Covered | curl_certificate TLS handshake |
| Device Management | `NC_Push_Notifications_assess-api.push.apple.com:443` | api.push.apple.com:443 | Covered | curl_certificate TLS handshake |
| Device Management | `NC_Push_Notifications_assess-api.push.apple.com:2197` | api.push.apple.com:2197 | Covered | curl_certificate TLS handshake; same host and port tested once |
| Device Management | `NC_Push_Notifications_assess-api.sandbox.push.apple.com:443` | api.sandbox.push.apple.com:443 | Covered | curl_certificate TLS handshake |
| Device Management | `NC_Push_Notifications_assess-api.sandbox.push.apple.com:2197` | api.sandbox.push.apple.com:2197 | Covered | curl_certificate TLS handshake |
| Device Management | `NC_Device_Management_assess-data.appattest.apple.com:443` | data.appattest.apple.com:443 | Covered | curl_certificate TLS handshake |
| Apple School Manager and Apple Business | `NC_Known_Apple_Networks_assess-upload.appleschoolcontent.com:22` | upload.appleschoolcontent.com:22 | Not covered | SFTP; osquery has no SSH probe |
| Apple School Manager and Apple Business | `NC_Device_Setup_assess-business.apple.com:443` | business.apple.com:443 | Covered | curl_certificate TLS handshake |
| Apple School Manager and Apple Business | `NC_Device_Setup_assess-school.apple.com:443` | school.apple.com:443 | Covered | curl_certificate TLS handshake |
| Apple School Manager and Apple Business | `NC_Device_Setup_assess-ws-ee-maidsvc.icloud.com:443` | ws-ee-maidsvc.icloud.com:443 | Covered | curl_certificate TLS handshake |
| Apple School Manager and Apple Business | `NC_AXM_assess-api.ent.apple.com:443` | api.ent.apple.com:443 | Covered | curl_certificate TLS handshake |
| Apple School Manager and Apple Business | `NC_AXM_assess-api.edu.apple.com:443` | api.edu.apple.com:443 | Covered | curl_certificate TLS handshake |
| Apple School Manager and Apple Business | `NC_AXM_assess-statici.icloud.com:443` | statici.icloud.com:443 | Covered | curl_certificate TLS handshake |
| Apple School Manager and Apple Business | `NC_AXM_assess-vertexsmb.com:443` | vertexsmb.com:443 | Covered | curl_certificate TLS handshake |
| Apple School Manager and Apple Business | `NC_AXM_assess-api-business.apple.com:443` | api-business.apple.com:443 | Covered | curl_certificate TLS handshake |
| Apple School Manager and Apple Business | `NC_AXM_assess-api-school.apple.com:443` | api-school.apple.com:443 | Covered | curl_certificate TLS handshake |
| Apple School Manager and Apple Business | `NC_Apps_And_Additional_Content_assess-www.apple.com:443` | www.apple.com:443 | Covered | curl_certificate TLS handshake |
| Apple School Manager and Apple Business | `NC_AXM_assess-wildcard-api.itunes.apple.com:443` | api.itunes.apple.com:443 | Covered | curl_certificate TLS handshake |
| Apple School Manager and Apple Business | `NC_AXM_assess-wildcard-s1.mzstatic.com:443` | s1.mzstatic.com:443 | Covered | curl_certificate TLS handshake |
| Apple Business Device Management | `NC_AXM_assess-cdn.apple-mapkit.com:443` | cdn.apple-mapkit.com:443 | Covered | curl_certificate TLS handshake |
| Apple Business Device Management | `NC_AXM_assess-axm-app.apple.com:443` | axm-app.apple.com:443 | Covered | curl_certificate TLS handshake |
| Apple Business Device Management | `NC_AXM_assess-axm-adm-scep.apple.com:443` | axm-adm-scep.apple.com:443 | Covered | curl_certificate TLS handshake |
| Apple Business Device Management | `NC_AXM_assess-axm-adm-mdm.apple.com:443` | axm-adm-mdm.apple.com:443 | Covered | curl_certificate TLS handshake |
| Apple Business Device Management | `NC_AXM_assess-axm-adm-enroll.apple.com:443` | axm-adm-enroll.apple.com:443 | Covered | curl_certificate TLS handshake |
| Apple Business Device Management | `NC_AXM_assess-icons.axm-usercontent-apple.com:443` | icons.axm-usercontent-apple.com:443 | Covered | curl_certificate TLS handshake |
| Classroom and Schoolwork | `NC_Apps_And_Additional_Content_assess-play.itunes.apple.com:443` | play.itunes.apple.com:443 | Covered | curl_certificate TLS handshake |
| Classroom and Schoolwork | `NC_AXM_assess-cls-ingest.itunes.apple.com:443` | cls-ingest.itunes.apple.com:443 | Covered | curl_certificate TLS handshake |
| Classroom and Schoolwork | `NC_AXM_assess-cls-iosclient.itunes.apple.com:443` | cls-iosclient.itunes.apple.com:443 | Covered | curl_certificate TLS handshake |
| Classroom and Schoolwork | `NC_AXM_assess-pg-bootstrap.itunes.apple.com:443` | pg-bootstrap.itunes.apple.com:443 | Covered | curl_certificate TLS handshake |
| Classroom and Schoolwork | `NC_AXM_assess-ws.school.apple.com:443` | ws.school.apple.com:443 | Covered | curl_certificate TLS handshake |
| Classroom and Schoolwork | `NC_AXM_assess-s.mzstatic.com:443` | s.mzstatic.com:443 | Covered | curl_certificate TLS handshake |
| Software Updates | `NC_SU_Servers_assess-ig.apple.com:443` | ig.apple.com:443 | Covered | curl_certificate TLS handshake |
| Software Updates | `NC_SU_Servers_assess-appldnld.apple.com:80` | appldnld.apple.com:80 | Covered | curl HTTP GET |
| Software Updates | `NC_SU_Servers_assess-updates-http.cdn-apple.com:80` | updates-http.cdn-apple.com:80 | Covered | curl HTTP GET |
| Software Updates | `NC_SU_Servers_assess-configuration.apple.com:443` | configuration.apple.com:443 | Covered | curl_certificate TLS handshake |
| Software Updates | `NC_Device_Setup_assess-oscdn.apple.com:443` | oscdn.apple.com:443 | Covered | curl_certificate TLS handshake |
| Software Updates | `NC_Device_Setup_assess-mesu.apple.com:443` | mesu.apple.com:443 | Covered | curl_certificate TLS handshake |
| Software Updates | `NC_Device_Setup_assess-gs.apple.com:443` | gs.apple.com:443 | Covered | curl_certificate TLS handshake; same host and port tested once |
| Software Updates | `NC_Device_Setup_assess-gg.apple.com:443` | gg.apple.com:443 | Covered | curl_certificate TLS handshake |
| Software Updates | `NC_Device_Setup_assess-swdownload.apple.com:443` | swdownload.apple.com:443 | Covered | curl_certificate TLS handshake |
| Software Updates | `NC_Device_Setup_assess-swcdn.apple.com:443` | swcdn.apple.com:443 | Covered | curl_certificate TLS handshake |
| Software Updates | `NC_Device_Setup_assess-osrecovery.apple.com:443` | osrecovery.apple.com:443 | Covered | curl_certificate TLS handshake |
| Software Updates | `NC_SU_Servers_assess-skl.apple.com:443` | skl.apple.com:443 | Covered | curl_certificate TLS handshake |
| Software Updates | `NC_Software_Update_assess-fcs-keys-pub-prod.cdn-apple.com:443` | fcs-keys-pub-prod.cdn-apple.com:443 | Covered | curl_certificate TLS handshake |
| Software Updates | `NC_Software_Update_assess-wkms-public.apple.com:443` | wkms-public.apple.com:443 | Covered | curl_certificate TLS handshake |
| Software Updates | `NC_Software_Update_assess-gsra.apple.com:443` | gsra.apple.com:443 | Covered | curl_certificate TLS handshake |
| Software Updates | `NC_Software_Update_assess-gdmf-ados.apple.com:443` | gdmf-ados.apple.com:443 | Covered | curl_certificate TLS handshake |
| Software Updates | `NC_Software_Update_assess-xp.apple.com:443` | xp.apple.com:443 | Covered | curl_certificate TLS handshake |
| Software Updates | `NC_Software_Update_assess-updates.cdn-apple.com:443` | updates.cdn-apple.com:443 | Covered | curl_certificate TLS handshake |
| Software Updates | `NC_Software_Update_assess-swscan.apple.com:443` | swscan.apple.com:443 | Covered | curl_certificate TLS handshake |
| Software Updates | `NC_Software_Update_assess-swdist.apple.com:443` | swdist.apple.com:443 | Covered | curl_certificate TLS handshake |
| Apps and Additional Content | `NC_App_And_Additional_Content_Servers_assess-meu.cdn-apple.com:443` | meu.cdn-apple.com:443 | Covered | curl_certificate TLS handshake |
| Apps and Additional Content | `NC_Notarization_Servers_assess-api.apple-cloudkit.com:443` | api.apple-cloudkit.com:443 | Covered | curl_certificate TLS handshake |
| Apps and Additional Content | `NC_App_And_Additional_Content_Servers_assess-mzstatic.com:443` | s1.mzstatic.com:443 | Covered | curl_certificate TLS handshake; same host and port tested once |
| Apps and Additional Content | `NC_Device_Setup_assess-itunes.apple.com:443` | itunes.apple.com:443 | Covered | curl_certificate TLS handshake |
| Apps and Additional Content | `NC_Device_Setup_assess-download.developer.apple.com:443` | download.developer.apple.com:443 | Covered | curl_certificate TLS handshake |
| Apps and Additional Content | `NC_Device_Setup_assess-sylvan.apple.com:443` | sylvan.apple.com:443 | Covered | curl_certificate TLS handshake |
| Apps and Additional Content | `NC_Device_Setup_assess-devimages-cdn.apple.com:443` | devimages-cdn.apple.com:443 | Covered | curl_certificate TLS handshake |
| Apps and Additional Content | `NC_Device_Setup_assess-audiocontentdownload.apple.com:443` | audiocontentdownload.apple.com:443 | Covered | curl_certificate TLS handshake |
| Apps and Additional Content | `NC_Apps_And_Additional_Content_assess-token.safebrowsing.apple:443` | token.safebrowsing.apple:443 | Covered | curl_certificate TLS handshake |
| Apps and Additional Content | `NC_Apps_And_Additional_Content_assess-amp-api.apps-marketplace.apple.com:443` | amp-api.apps-marketplace.apple.com:443 | Covered | curl_certificate TLS handshake |
| Apps and Additional Content | `NC_Apps_And_Additional_Content_assess-ppq.apple.com:443` | ppq.apple.com:443 | Covered | curl_certificate TLS handshake |
| Apps and Additional Content | `NC_Apps_And_Additional_Content_assess-apps.apple.com:443` | apps.apple.com:443 | Covered | curl_certificate TLS handshake |
| Apps and Additional Content | `NC_Accessibility_assess-data.gateway.icloud.com:443` | gateway.icloud.com:443 | Covered | curl_certificate TLS handshake |
| Apps and Additional Content | `NC_Apps_And_Additional_Content_assess-playgrounds-cdn.apple.com:443` | playgrounds-cdn.apple.com:443 | Covered | curl_certificate TLS handshake |
| Apps and Additional Content | `NC_Additional_Content_assess-playgrounds-assets-cdn.apple.com:443` | playgrounds-assets-cdn.apple.com:443 | Covered | curl_certificate TLS handshake |
| Apps and Additional Content | `NC_Additional_Content_assess-data.appattest.apple.com:443` | data.appattest.apple.com:443 | Covered | curl_certificate TLS handshake; same host and port tested once |
| Apps and Additional Content | `NC_Apps_And_Additional_Content_assess-wildcard-ax.itunes.apple.com:443` | ax.itunes.apple.com:443 | Covered | curl_certificate TLS handshake |
| Carrier Updates | `NC_SU_Servers_assess-itunes.com:80` | itunes.com:80 | Covered | curl HTTP GET |
| Carrier Updates | `NC_SU_Servers_assess-appldnld.apple.com.edgesuite.net:80` | appldnld.apple.com.edgesuite.net:80 | Covered | curl HTTP GET |
| Carrier Updates | `NC_Carrier_Updates_assess-appldnld.apple.com:80` | appldnld.apple.com:80 | Covered | curl HTTP GET; same host and port tested once |
| Carrier Updates | `NC_Carrier_Updatess_assess-updates-http.cdn-apple.com:80` | updates-http.cdn-apple.com:80 | Covered | curl HTTP GET; same host and port tested once |
| Carrier Updates | `NC_Carrier_Updatese_assess-itunes.apple.com:443` | itunes.apple.com:443 | Covered | curl_certificate TLS handshake; same host and port tested once |
| Carrier Updates | `NC_Carrier_Updates_assess-updates.cdn-apple.com:443` | updates.cdn-apple.com:443 | Covered | curl_certificate TLS handshake; same host and port tested once |
| Content Caching | `NC_Content_Caching_Servers_assess-suconfig.apple.com:80` | suconfig.apple.com:80 | Covered | curl HTTP GET |
| Content Caching | `NC_Content_Caching_assess-xp-cdn.apple.com:443` | xp-cdn.apple.com:443 | Covered | curl_certificate TLS handshake |
| Content Caching | `NC_Content_Caching_assess-serverstatus.apple.com:443` | serverstatus.apple.com:443 | Covered | curl_certificate TLS handshake |
| Content Caching | `NC_Content_Caching_assess-lcdn-registration.apple.com:443` | lcdn-registration.apple.com:443 | Covered | curl_certificate TLS handshake |
| Content Caching | `NC_Content_Caching_assess-lcdn-locator.apple.com:443` | lcdn-locator.apple.com:443 | Covered | curl_certificate TLS handshake |
| Beta Updates | `NC_Feedback_Assistant_assess-fba.apple.com:443` | fba.apple.com:443 | Covered | curl_certificate TLS handshake |
| Beta Updates | `NC_Feedback_Assistant_assess-cssubmissions.apple.com:443` | cssubmissions.apple.com:443 | Covered | curl_certificate TLS handshake |
| Beta Updates | `NC_Feedback_Assistant_assess-bpapi.apple.com:443` | bpapi.apple.com:443 | Covered | curl_certificate TLS handshake |
| Apple Diagnostics | `NC_Apple_Diagnostics_assess-diagassets.apple.com:443` | diagassets.apple.com:443 | Covered | curl_certificate TLS handshake |
| Domain Name System Resolution | `NC_DNS_Resolution_assess-doh.dns.apple.com:443` | doh.dns.apple.com:443 | Covered | curl_certificate TLS handshake |
| Certificate Validation | `NC_Cert_Validation_Servers_assess-crl.apple.com:80` | crl.apple.com:80 | Covered | curl HTTP GET |
| Certificate Validation | `NC_Cert_Validation_Servers_assess-crl3.digicert.com:80` | crl3.digicert.com:80 | Covered | curl HTTP GET |
| Certificate Validation | `NC_Cert_Validation_Servers_assess-crl4.digicert.com:80` | crl4.digicert.com:80 | Covered | curl HTTP GET |
| Certificate Validation | `NC_Device_Setup_assess-certs.apple.com:443` | certs.apple.com:443 | Covered | curl_certificate TLS handshake |
| Certificate Validation | `NC_Cert_Validation_Servers_assess-ocsp.apple.com:80` | ocsp.apple.com:80 | Covered | curl HTTP GET |
| Certificate Validation | `NC_Cert_Validation_Servers_assess-ocsp.digicert.com:80` | ocsp.digicert.com:80 | Covered | curl HTTP GET |
| Certificate Validation | `NC_Cert_Validation_assess-valid.apple.com:443` | valid.apple.com:443 | Covered | curl_certificate TLS handshake |
| Certificate Validation | `NC_Cert_Validation_assess-ocsp2.apple.com:443` | ocsp2.apple.com:443 | Covered | curl_certificate TLS handshake |
| Apple Account | `NC_Apple_Id_assess-account.apple.com:443` | account.apple.com:443 | Covered | curl_certificate TLS handshake |
| Apple Account | `NC_Apple_Id_assess-gsa.apple.com:443` | gsa.apple.com:443 | Covered | curl_certificate TLS handshake |
| Apple Account | `NC_Apple_Id_assess-idmsa.apple.com:443` | idmsa.apple.com:443 | Covered | curl_certificate TLS handshake |
| Apple Account | `NC_Apple_Id_assess-appleid.cdn-apple.com:443` | appleid.cdn-apple.com:443 | Covered | curl_certificate TLS handshake |
| iCloud | `NC_iCloud_Private_Relay_assess-mask.icloud.com:443` | mask.icloud.com:443 | Covered | curl_certificate TLS handshake |
| iCloud | `NC_iCloud_Private_Relay_assess-mask-h2.icloud.com:443` | mask-h2.icloud.com:443 | Covered | curl_certificate TLS handshake |
| iCloud | `NC_iCloud_mask-api.icloud.com:443` | mask-api.icloud.com:443 | Covered | curl_certificate TLS handshake |
| iCloud | `NC_Device_Management_assess-publish.iwork.apple.com:443` | publish.iwork.apple.com:443 | Covered | curl_certificate TLS handshake |
| iCloud | `NC_Device_Management_assess-cdn.icloud-content.com:443` | cdn.icloud-content.com:443 | Covered | curl_certificate TLS handshake |
| iCloud | `NC_iCloud_assess-wildcard-api.icloud.apple.com:443` | api.icloud.apple.com:443 | Covered | curl_certificate TLS handshake |
| iCloud | `NC_iCloud_assess-wildcard-setup.icloud.com:443` | setup.icloud.com:443 | Covered | curl_certificate TLS handshake; same host and port tested once |
| iCloud | `NC_Device_Management_assess-cdn.apple-livephotoskit.com:443` | cdn.apple-livephotoskit.com:443 | Covered | curl_certificate TLS handshake |
| iCloud | `NC_Device_Management_assess-cdn.apple-cloudkit.com:443` | cdn.apple-cloudkit.com:443 | Covered | curl_certificate TLS handshake |
| iCloud | `NC_iCloud_assess-wildcard-meu.cdn-apple.com:443` | meu.cdn-apple.com:443 | Covered | curl_certificate TLS handshake; same host and port tested once |
| iCloud | `NC_iCloud_assess-wildcard-gc.apple.com:443` | friend.gc.apple.com:443 | Covered | curl_certificate TLS handshake |
| iCloud | `NC_iCloud_assess-probe.icloud.com:443` | probe.icloud.com:443 | Covered | curl_certificate TLS handshake |
| iCloud | `NC_iCloud_assess-metrics.icloud.com:443` | metrics.icloud.com:443 | Covered | curl_certificate TLS handshake |
| iCloud | `NC_iCloud_assess-apple-native-relay.apple.com:443` | apple-native-relay.apple.com:443 | Covered | curl_certificate TLS handshake |
| Apple Intelligence, Siri, and Search | `NC_Apple_Intelligence_assess-cp4.cloudflare.com:443` | cp4.cloudflare.com:443 | Covered | curl_certificate TLS handshake |
| Apple Intelligence, Siri, and Search | `NC_Apple_Intelligence_apple-relay.apple.com:443` | apple-relay.apple.com:443 | Covered | curl_certificate TLS handshake |
| Apple Intelligence, Siri, and Search | `NC_DNS_Resolution_assess-cdn.smoot.apple.com:443` | cdn.smoot.apple.com:443 | Covered | curl_certificate TLS handshake |
| Apple Intelligence, Siri, and Search | `NC_DNS_Resolution_assess-guzzoni.apple.com:443` | guzzoni.apple.com:443 | Covered | curl_certificate TLS handshake |
| Apple Intelligence, Siri, and Search | `NC_AI_Siri_Search_apple-relay.fastly-edge.com:443` | apple-relay.fastly-edge.com:443 | Covered | curl_certificate TLS handshake |
| Apple Intelligence, Siri, and Search | `NC_AI_Siri_Search_apple-relay.cloudflare.com:443` | apple-relay.cloudflare.com:443 | Covered | curl_certificate TLS handshake |
| Associated Domains | `NC_Additional_Content_assess-app-site-association.cdn-apple.com:443` | app-site-association.cdn-apple.com:443 | Covered | curl_certificate TLS handshake |
| Associated Domains | `NC_Additional_Content_assess-app-site-association.networking.apple:443` | app-site-association.networking.apple:443 | Covered | curl_certificate TLS handshake |
| Tap to Pay on iPhone | `NC_Tap_to_Pay_assess-humb.apple.com:443` | humb.apple.com:443 | Covered | curl_certificate TLS handshake; same host and port tested once |
| Tap to Pay on iPhone | `NC_Tap_to_Pay_assess-pos-device.apple.com:443` | pos-device.apple.com:443 | Covered | curl_certificate TLS handshake |
| Tap to Pay on iPhone | `NC_Tap_to_Pay_assess-iphonesubmissions.apple.com:443` | iphonesubmissions.apple.com:443 | Covered | curl_certificate TLS handshake |
| ID Verifier on iPhone | `NC_ID_Verifier_assess-smp-device-content.apple.com:443` | smp-device-content.apple.com:443 | Covered | curl_certificate TLS handshake |
| ID Verifier on iPhone | `NC_ID_Verifier_assess-idv.cdn-apple.com:443` | idv.cdn-apple.com:443 | Covered | curl_certificate TLS handshake |
| ID Verifier on iPhone | `NC_ID_Verifier_assess-idv-prod1.apple.com:443` | idv-prod1.apple.com:443 | Covered | curl_certificate TLS handshake |
| ID Verifier on iPhone | `NC_ID_Verifier_assess-humb.apple.com:443` | humb.apple.com:443 | Covered | curl_certificate TLS handshake; same host and port tested once |
| ApplePushService Daemon | `ANR_assess-APNS_Reachability` | apsctl status | Not covered | Reads apsd's connection state; the courier host checks cover reachability |
