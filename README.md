# Office365_Scripts
 Various scripts to assist with automation, management, and deployment of Office 365 that I created or tweaked from public code snippets. Any tweaked code snippets belong to their original authors. Almost all scripts have some in-code documentation at least. **See comment headers for additional details on each script.**
 
 ## All-In-One Automation
 
 **O365_Offboarding.ps1**: Comprehensive script that can perform various common offboarding tasks using various official Powershell modules, in both a hybrid and O365-only environment. **Fully documented.**
 
 **O365_Reenable_after_Offboarding.ps1**: Similar to the O365_Offboarding.ps1 script, performing tasks using various official Powershell modules to re-enable an account that's been previously offboarded. **Fully documented.**
 
 ## Azure AD

 **AAD-Get-LastLogins.ps1**: Powershell script to get the last logins for the given UPN from the UnifiedAuditLog. Requires Microsoft Exchange Online Powershell Module.
 
 **AAD-Get-PasswordPolicy-For-Inactive-Users.ps1**: Powershell script to show the password policies and LastPasswordChangeTimestamp set in Azure AD for users with expired passwords (default: no change in 90 days), for help figuring out why passwords may not be expiring correctly online. Requires both the MSOnline and Azure AD (Azure Active Directory PowerShell for Graph) modules. Hint: If you're using a Hybrid AD environment without writeback, look at the *EnforceCloudPasswordPolicyForPasswordSyncedUsers* option in Azure AD / Microsoft Online.
 
 ## Hybrid AD
 
 **HybridAD-Get-InactiveUsers.ps1**: Powershell script to get inactive users (default: no logins or password changes in 90 days) in a hybrid AD environment, using a UnifiedAuditLog search to compare against results in Microsoft Online. Requires Microsoft Exchange Online Powershell module.
 
 ## Exchange Online
 
 **EXO-Convert-Mailboxes-to-Shared.ps1**: Powershell script to convert given user mailboxes to shared mailboxes in Exchange Online, removing their licenses afterwards; userful for offboarding. Requires Microsoft Exchange Online Powershell module.
 
 **EXO-Create-Migration-Batch.ps1**: Powershell script to assign licenses and location to given UPNs and then setup a migration batch from on-prem Exchange to Exchange Online. Requires Microsoft Exchange Online Powershell module.
 
 **EXO-GetMailboxBlockedSenders.ps1**: Powershell script to get and search the blocked and junk sender list of a particular mailbox in Exchange Online (not the global list, but the list specific to a mailbox). Requires Microsoft Exchange Online Powershell module.
 
 ## OneDrive and Sharepoint Online
 
 **OD-Get-OneDriveInactivity.ps1**: Powershell script which attempts to report on possible sync problems by looking at both OneDrive / Sharepoint and overall login activities over a period of time (default: past 7 days) as currently there is no centralized way of reporting on or polling OneDrive sync problems. Requires Sharepoint Online and Exchange Online Powershell modules.
 
 **OD-Get-OneDriveActivityRESTReport.ps1**: Powershell script which uses the Microsoft Graph REST API to report on possible OneDrive inactivity / sync problems. No extra modules required.
 
 **SPM-Export-Folders-at-Path-to-CSV.ps1**: Powershell script to export directory structure at given path to CSV for import into the Sharepoint Migration Tool. Don't think this is really needed anymore in 2020 and on.
 
 ## Office 365 and Microsoft Online
 
 **O365-Get-LicenseReconiliationNeeded.ps1**: Powershell script to show a report of all online users flagged with LicenseReconiliationNeeded. Accounts with this flag may be deleted by Microsoft after 30 days. Requires official MSOnline Powershell module.
 
 **O365-Get-LicenseUsage-Report.ps1**: Powershell script to show a report of all license usage.
 
 ## Office 365 Deployment
 **O365_Check_Deployment_Logs_For_Failure.bat**: Windows batch script to check given Office 365 Deployment Tool logs for possible failures or critical errors.
 
 
 
