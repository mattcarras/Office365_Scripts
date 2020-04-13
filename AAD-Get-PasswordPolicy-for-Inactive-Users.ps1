# Show password policy for users with expired passwords
# Hint: For hybrid AD environments, look into the EnforceCloudPasswordPolicyForPasswordSyncedUsers option.
Import-Module MSOnline
Connect-MsolService
Connect-AzureAD
Get-MsolUser -All -EnabledFilter EnabledOnly | Where { $_.isLicensed -and $_.LastPasswordChangeTimestamp -lt (Get-Date).AddDays(-90) } | ForEach { Write-Output( $_.UserPrincipalName + " - " + (Get-AzureADUser -objectID $_.UserPrincipalName).passwordpolicies) }
