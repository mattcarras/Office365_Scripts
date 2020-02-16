# Quick script to check LicenseReconciliationNeeded flag
# This flag can indicate if a mailbox or account is in danger of being deleted after 30 days of no applicable licenses added
# Can also show up for accounts synced from on-prem AD with no mailboxes or resources
# Last Updated: 2-16-20 Matt Carras

Import-Module MSOnline
Connect-MsolService

Get-MsolUser -All -LicenseReconciliationNeededOnly | Select-Object UserPrincipalName, IsLicensed, LicenseReconciliationNeeded, Licenses | Out-GridView

# Pause until a key is pressed
Write-Output ("Press any key to continue...")
$HOST.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | OUT-NULL
$HOST.UI.RawUI.Flushinputbuffer()
