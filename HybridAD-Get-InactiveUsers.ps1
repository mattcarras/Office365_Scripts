# Gets last login date from mailbox in EXO for hybrid environments
# Only gets enabled users with expiring passwords
# - Requires Microsoft Exchange Online Powershell Module shell
# Last Updated: 2-28-20 MattC
# TODO: Verify results from Get-MsolUser for online-only user accounts

#Import MSOL Module
#Import-Module MSOnline -ErrorAction Stop
 
#Import Exchange Online Module for Search-UnifiedAuditLog
Import-Module $((Get-ChildItem -Path $($env:LOCALAPPDATA + "\Apps\2.0\") -Filter Microsoft.Exchange.Management.ExoPowershellModule.dll -Recurse).FullName | ?{ $_ -notmatch "_none_" } | select -First 1) -ErrorAction Stop

# -- START CONFIGURATION --
# UPN to use to login to EXO. Should be same as inputting into Connect-MsolService to avoid double prompt
#$adminUPN = 'mcarrasadmin@metacoastal.onmicrosoft.com'

# Date to compare against (90 days from current date)
$inactiveAfterDate = (Get-Date).AddDays(-90)

# -- END CONFIGURATION --

# Write-Output('** Logging into Microsoft Online...')
# Connect-MsolService -ErrorAction Stop

Write-Output('** Logging into Exchange Online...')
#$EXOSession = New-ExoPSSession -UserPrincipalName $adminUPN -ErrorAction Stop
$EXOSession = New-ExoPSSession -ErrorAction Stop
Import-PSSession $EXOSession -AllowClobber

# Get all enabled users with expiring passwords that seemingly have not logged in for the past 90 days, but only if user was created over 90 days ago
Write-Output('** Collecting information from AD...')
$inactiveUsersAD = Get-ADUser -Filter {Enabled -eq $TRUE -and PasswordNeverExpires -ne $TRUE} -Properties Name,SamAccountName,UserPrincipalName,LastLogonDate,PasswordLastSet,WhenCreated | Select Name,UserPrincipalName,LastLogonDate,PasswordLastSet,whenCreated | Where {(($_.LastLogonDate -eq $NULL) -or ($_.LastLogonDate -lt $inactiveAfterDate) -or ($_.PasswordLastSet -lt $inactiveAfterDate)) -And ($_.WhenCreated -lt $inactiveAfterDate)}

# Write-Output('** Collecting information from Microsoft Online...')
# $inactiveUsersMSOL = Get-MsolUser -All -EnabledFilter EnabledOnly | Where {$_.IsLicensed -eq $TRUE -And $_.PasswordNeverExpires -ne $TRUE -And $_.WhenCreated -lt $inactiveAfterDate} | Select @{Name='Name';Expression={$_.DisplayName}},UserPrincipalName,@{Name='LastLogonDate';Expression={$null}},@{Name='PasswordLastSet';Expression={$_.LastPasswordChangeTimestamp}},WhenCreated | Where {-Not $_.PasswordLastSet -lt $inactiveAfterDate -And $inactiveUsersAD -NotContains $_.UserPrincipalName}

# $inactiveUsers = $inactiveUsersAD + $inactiveUsersMSOL # Create user superset

$inactiveUsers = $inactiveUsersAD

# Get all users that have logged on in the past 90 days, filtered by previous result
Write-Output('** Collecting information from EXO and comparing it to AD...')
$loggedOnUsers = Search-UnifiedAuditLog -StartDate ($inactiveAfterDate.ToString('MM/dd/yyyy')) -EndDate ((Get-Date).ToString('MM/dd/yyyy')) -Operations UserLoggedIn,PasswordLogonInitialAuthUsingPassword,UserLoginFailed -ResultSize 5000 -UserIds ($inactiveUsers | Select -ExpandProperty UserPrincipalName) | Select UserIds

# Display resulting set where inactive users do NOT appear in Search-UnifiedAuditLog
$inactiveUsers | where {$loggedOnUsers.UserIds -NotContains $_.UserPrincipalName} | Out-GridView

Remove-PSSession $EXOSession

# Pause until a key is pressed
Write-Output ("Done. Press any key to continue...")
$HOST.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | OUT-NULL
$HOST.UI.RawUI.Flushinputbuffer()
