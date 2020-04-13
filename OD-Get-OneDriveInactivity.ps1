# Last Updated: 4-13-20 MattC
# Requires Sharepoint Online and Exchange Online Powershell Modules
#Import Sharepoint Online Management Shell
Import-Module Microsoft.Online.SharePoint.PowerShell -DisableNameChecking -ErrorAction Stop
 
#Import Exchange Online Module for Search-UnifiedAuditLog
Import-Module $((Get-ChildItem -Path $($env:LOCALAPPDATA + "\Apps\2.0\") -Filter Microsoft.Exchange.Management.ExoPowershellModule.dll -Recurse).FullName | ?{ $_ -notmatch "_none_" } | select -First 1) -ErrorAction Stop

# -- Start Configuration --

$tenantID = 'contoso'
$sharepointAdminURL = "https://$tenantID-admin.sharepoint.com"
$adminUPN = "contosoadmin@$tenantID.onmicrosoft.com"
$checkDaysStart = 7 # Check up to 7 days in the past

# -- End Configuration --

$checkDate = (Get-Date).AddDays(-1 * $checkDaysStart)

Write-Output('** Logging into Sharepoint Online...')
Connect-SPOService -Url $sharepointAdminURL -ErrorAction Stop

Write-Output('** Logging into Exchange Online...')
$EXOSession = New-ExoPSSession -UserPrincipalName $adminUPN -ErrorAction Stop
Import-PSSession $EXOSession -AllowClobber

Write-Output('** Getting list of enabled users from on-prem AD...')
$enabledADUsers = Get-ADUser -Filter {Enabled -eq $TRUE} -Properties UserPrincipalName | Select -ExpandProperty UserPrincipalName

Write-Output('** Getting list of OneDrive users from Sharepoint Online...')
$odUsers = Get-SPOSite -IncludePersonalSite $true -Limit all -Filter "Url -like '-my.sharepoint.com/personal/'" | Where {$_.Status -eq 'Active' -And $_.StorageUsageCurrent -gt 1 -And $enabledADUsers -contains $_.Owner} | Sort-Object -Property Owner -Unique | Select -ExpandProperty Owner

Write-Output('** Getting list of active users from UnifiedAuditLog via Exchange Online...')
$loggedOnUsers = Search-UnifiedAuditLog -StartDate ($checkDate.ToUniversalTime()) -EndDate ((Get-Date).ToUniversalTime()) -Operations UserLoggedIn,PasswordLogonInitialAuthUsingPassword,UserLoginFailed -ResultSize 5000 -UserIds $odUsers | Sort-Object -Property UserIds -Unique | Select -ExpandProperty UserIds

Write-Output('** Collecting OneDrive activity from UnifiedAuditLog for each user...')
ForEach ($userId in $loggedOnUsers) {
	$result = Search-UnifiedAuditLog -StartDate ($checkDate.ToUniversalTime()) -EndDate ((Get-Date).ToUniversalTime()) -RecordType OneDrive -Operations FileSyncUploadedFull,FileSyncUploadedPartial,FileUploaded,FileModified,FileRenamed,FileMoved,FileDeleted -ResultSize 3 -UserIds $userId
	If (! $result ) { 
		Write-Output("** [$userId] has NO OneDrive activity in last $checkDaysStart days **")
	} else {
		Write-Output("[$userId] has OneDrive activity in last $checkDaysStart days")
	}
} #end foreach

Remove-PSSession $EXOSession