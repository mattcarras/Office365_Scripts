# Converts mailboxes for given user IDs to shared and then remove licenses
# Requires: 
# - Microsoft Azure Active Directory Module for Windows PowerShell (Msol)
# - Microsoft Exchange Online Powershell Module
# Last Updated: 3-26-2020 MJC

#Import MSOline Module
Import-Module MSOnline
 
#Import Exchange Online Module
Import-Module $((Get-ChildItem -Path $($env:LOCALAPPDATA + "\Apps\2.0\") -Filter Microsoft.Exchange.Management.ExoPowershellModule.dll -Recurse).FullName | ?{ $_ -notmatch "_none_" } | select -First 1)

#Set admin UPN
$UPN = 'mcarrasadmin@metacoastal.onmicrosoft.com'

# Get mailboxes from user input
# Load VB assembly for InputBox
$sUserIDs=""
Write-Output ("*** Waiting for user input...")
[void][Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic')
$sTitle = 'Input mailboxes to convert'
$sMsg = 'Please enter comma-separated user IDs with mailboxes to convert to shared: '
$sUserIDs = [Microsoft.VisualBasic.Interaction]::InputBox($sMsg, $sTitle)

# sanity check
If ( [string]::IsNullOrEmpty($sUserIDs) -Or [string]::IsNullOrWhitespace($sUserIDs) ) {
	Write-Output ("*** ERROR - No user ID(s) given. Aborting.")
} Else {
	Write-Output ("*** Connecting to Azure AD (Msol) and Exchange Online using UPN [{0}]..." -f $UPN)
	Connect-MsolService -ErrorAction Stop
	$EXOSession = New-ExoPSSession -UserPrincipalName $UPN -ErrorAction Stop
	Import-PSSession $EXOSession -AllowClobber

	Write-Output ("*** UserIDs given: $sUserIDs")
	$sUserIDs = $sUserIDs -split ','
	
	ForEach ($mailbox in $sUserIDs) {
		Write-Output ("*** Converting {0} to shared..." -f $mailbox)
		Set-Mailbox $mailbox -Type shared
	} #end foreach

	# Remove all licenses for each given user ID
	ForEach ($userID in $sUserIDs) {
		Write-Output ("*** Removing all licenses from {0} in Azure AD..." -f $userID)
		Try {
			(Get-MsolUser -UserPrincipalName $userID).licenses.AccountSkuId | Set-MsolUserLicense -UserPrincipalName $userID -RemoveLicenses $_
		} Catch {
			Write-Output ("*** WARNING: {0} not found in Azure AD or another error occurred removing licenses" -f $userID)
		} #end try/catch
	} #end foreach
	
	Remove-PSSession $EXOSession
} # end if

# Pause until a key is pressed
Write-Output ("Done. Press any key to continue...")
$HOST.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | OUT-NULL
$HOST.UI.RawUI.Flushinputbuffer()