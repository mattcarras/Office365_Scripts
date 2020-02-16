# Creates an Exchange on-prem to Online Migration batch, attempting to assign proper licensing before migration.
# Requires: 
# - Microsoft Azure Active Directory Module for Windows PowerShell
# - Microsoft Exchange Online Powershell Module
# NOTE: Must be run from the Exchange Online Powershell shell.
# Last Updated: 2-16-2020 Matt Carras

## START REQUIRED CONFIGURATION ##
$sTargetDeliveryDomain = "contoso.mail.onmicrosoft.com" 				# your tenant domain goes here
$sNotifyEmailAddresses = "admin@contoso.com" 							# email to send migration notifications to
$sLicensesToAssign = "contoso:ATP_ENTERPRISE","contoso:ENTERPRISEPACK"	# O365 licenses to assign each user before migration
																		# You can use O365-Get-LicenseUsage-Report.ps1 to get these values
$sUsageLocation = "US"													# Usage location for assigning licenses (required)
## END REQUIRED CONFIGURATION ##

## START OPTIONAL CONFIGURATION ##
# Shouldn't need to change these limits, but go ahead. They refer to limits on migrating items in the mailbox.
$sBadItemLimit = "100"
$sLargeItemLimit = "100"
## END OPTIONAL CONFIGURATION ##

Write-Output('** NOTE: Make sure you are running from the Exchange Online Powershell Module shell')

# These will be populated below. We're just initializing them here.
$sUserIDs=""
$sBatchName=""

# Get batch name and mailboxes from user input
# Load VB assembly for InputBox
Write-Output ("{0}: Waiting for user input...")
[void][Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic')
$sTitle = 'Input mailboxes to migrate'
$sMsg = 'Please enter comma-separated user IDs to migrate up to Exchange Online: '
$sUserIDs = [Microsoft.VisualBasic.Interaction]::InputBox($sMsg, $sTitle)

# sanity check
If ( [string]::IsNullOrEmpty($sUserIDs) -Or [string]::IsNullOrWhitespace($sUserIDs) ) {
	Write-Output ("{0}: ERROR - No user ID(s) given. Aborting.")
} Else {
	# TODO: Combine MFA-capable authentication so user doesn't get prompted twice
	# Connect to Azure AD using Microsoft Azure Active Directory Module for Windows PowerShell
	Write-Output ("{0}: Connecting to Azure AD...")
	Import-Module MSOnline
	Connect-MsolService

	# Assign all 365 licenses to each user
	ForEach ($userID in $sUserIDs) {
		Write-Output ("{0}: Adding location and licenses to {1}..." -f $userID)
		Set-MsolUser -UserPrincipalName $userID -UsageLocation $sUsageLocation
		Set-MsolUserLicense -UserPrincipalName $userID -AddLicenses $sLicensesToAssign
	}

	# Connect to Exchange Online using Microsoft Exchange Online Powershell Module
	Write-Output ("{0}: Connecting to Exchange Online...")
	Connect-EXOPSSession

	Write-Output ("{0}: Waiting for user input...")
	$sTitle = 'Input batch name'
	$sMsg = 'Please enter a name for this new batch: '
	$sBatchName = [Microsoft.VisualBasic.Interaction]::InputBox($sMsg, $sTitle)

	# sanity check
	If ( [string]::IsNullOrEmpty($sBatchName) -Or [string]::IsNullOrWhitespace($sBatchName) ) {
		Write-Output ("{0}: ERROR - No batch name given. Aborting.")
	} Else {
		# This migration batch will autostart and autocomplete.
		Write-Output ("{0}: Creating new migration batch named [{1}]..." -f $sBatchName)
		New-MigrationBatch -Name $sBatchName -UserIds $sUserIDs -AutoStart -AutoComplete -BadItemLimit $sBadItemLimit -LargeItemLimit $sLargeItemLimit -TargetDeliveryDomain $sTargetDeliveryDomain -NotificationEmails $sNotifyEmailAddresses
	} # end if
} # end if

# Pause until a key is pressed
Write-Output ("Done. Press any key to continue...")
$HOST.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | OUT-NULL
$HOST.UI.RawUI.Flushinputbuffer()
