# Gets last login dates from Azure AD / O365 for UPN using UnifiedAuditLog query
# - Requires Microsoft Exchange Online Powershell Module
# Last Updated: 3-20-20 MattC
 
#Import Exchange Online Module for Search-UnifiedAuditLog
Import-Module $((Get-ChildItem -Path $($env:LOCALAPPDATA + "\Apps\2.0\") -Filter Microsoft.Exchange.Management.ExoPowershellModule.dll -Recurse).FullName | ?{ $_ -notmatch "_none_" } | select -First 1) -ErrorAction Stop

# -- START CONFIGURATION --

$startDate = (Get-Date).AddDays(-90) # How far back to go in the search (default: 90 days)
$iResultSize = 10					 # Max number of results to return (default: 10)

# -- END CONFIGURATION --

# Load VB assembly for InputBox
Write-Output ("*** Waiting for user input...")
[void][Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic')
$sTitle = 'Input UPN/UserID'
$sMsg = 'Please enter the UPN or UserID to get last logins: '
$sUserIDs = [Microsoft.VisualBasic.Interaction]::InputBox($sMsg, $sTitle)

# sanity check
If ( [string]::IsNullOrEmpty($sUserIDs) -Or [string]::IsNullOrWhitespace($sUserIDs) ) {
	Write-Output ("*** ERROR - No user ID(s) given. Aborting.")
} Else {
	Write-Output('*** Logging into Exchange Online...')
	$EXOSession = New-ExoPSSession -ErrorAction Stop
	Import-PSSession $EXOSession -AllowClobber
	
	Search-UnifiedAuditLog -StartDate ($startDate.ToString('MM/dd/yyyy')) -EndDate ((Get-Date).ToString('MM/dd/yyyy')) -Operations UserLoggedIn,PasswordLogonInitialAuthUsingPassword,UserLoginFailed -ResultSize $iResultSize -UserIDs $sUserIDs | Select UserIds,CreationDate,Operations,RecordType,IsValid | Out-GridView
	
	Remove-PSSession $EXOSession
} #end if (sanity check)

# Pause until a key is pressed
Write-Output ("Done. Press any key to continue...")
$HOST.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | OUT-NULL
$HOST.UI.RawUI.Flushinputbuffer()