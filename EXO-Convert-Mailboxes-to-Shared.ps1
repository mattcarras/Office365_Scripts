# Converts mailboxes for given user IDs to shared and then remove licenses
# Requires: 
# - Microsoft Azure Active Directory Module for Windows PowerShell
# - Microsoft Exchange Online Powershell Module
# NOTE: Must be run in the Exchange Online Powershell shell.
# Last Updated: 2-16-20 Matt Carras

## START CONFIGURATION ##
$sLicensesToRemove = "contoso:ATP_ENTERPRISE","contoso:ENTERPRISEPACK" # You can use O365-Get-LicenseUsage-Report.ps1 to get these values
																	   # Set it to "ALL" to remove ALL licenses found
## END CONFIGURATION ##

Write-Output('** NOTE: Make sure you are running from the Exchange Online Powershell Module shell')

# This will be populated below.
$sUserIDs=""

# Get mailboxes from user input
# Load VB assembly for InputBox
Write-Output ("{0}: Waiting for user input...")
[void][Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic')
$sTitle = 'Input mailboxes to convert'
$sMsg = 'Please enter comma-separated user IDs with mailboxes to convert to shared: '
$sUserIDs = [Microsoft.VisualBasic.Interaction]::InputBox($sMsg, $sTitle)

# sanity check
If ( [string]::IsNullOrEmpty($sUserIDs) -Or [string]::IsNullOrWhitespace($sUserIDs) ) {
	Write-Output ("{0}: ERROR - No user ID(s) given. Aborting.")
} Else {	
	# TODO: Combine MFA-capable authentication so user doesn't get prompted twice
	# Connect to Exchange Online using Microsoft Exchange Online Powershell Module
	Write-Output ("{0}: Connecting to Exchange Online...")
	Connect-EXOPSSession

	ForEach ($mailbox in $sUserIDs) {
		Write-Output ("{0}: Converting {1} to shared..." -f $mailbox)
		Set-Mailbox $mailbox -Type shared
	} #end foreach

	# Connect to Azure AD using Microsoft Azure Active Directory Module for Windows PowerShell
	Write-Output ("{0}: Connecting to Azure AD...")
	Import-Module MSOnline
	Connect-MsolService

	ForEach ($userID in $sUserIDs) {
		If ( $sLicensesToRemove -is "ALL" ) {
			Write-Output ("{0}: Removing ALL licenses found from {1}..." -f $userID)
			$sLicenses = Get-MsolUser -UserPrincipalName $userID | Select -ExpandProperty licenses﻿
			Set-MsolUserLicense -UserPrincipalName $userID -RemoveLicenses $sLicenses
		} Else {
			Write-Output ("{0}: Removing given licenses from {1}..." -f $userID)
			Set-MsolUserLicense -UserPrincipalName $userID -RemoveLicenses $sLicensesToRemove
		} #end if
	} #end foreach
} # end if

# Pause until a key is pressed
Write-Output ("Done. Press any key to continue...")
$HOST.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | OUT-NULL
$HOST.UI.RawUI.Flushinputbuffer()