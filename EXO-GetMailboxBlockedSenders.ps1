# Get BlockedSendersAndDomains from EXO mailbox
# Optional: Also allows searching said blocklist
# Separate multiple mailboxes and multiple search strings with commas
# REQUIRES: Must be run under Microsoft Exchange Online Powershell Module
# Uses VisualBasic InputBox
# Last Updated: 3-26-20 MattC

#Import Exchange Online Module
Import-Module $((Get-ChildItem -Path $($env:LOCALAPPDATA + "\Apps\2.0\") -Filter Microsoft.Exchange.Management.ExoPowershellModule.dll -Recurse).FullName | ?{ $_ -notmatch "_none_" } | select -First 1)

# Load VB assembly for InputBox
[void][Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic')
$sTitle = 'Get BlockedSendersAndDomains for EXO mailbox(es)'
$sMsg = 'Enter email address(es), multiple separated by commas: '
$sEmailAddress = [Microsoft.VisualBasic.Interaction]::InputBox($sMsg, $sTitle)

$sTitle = 'Blocked address(es) to search for'
$sMsg = 'Enter email address(es), multiple separated by commas, blank for none, partial accepted: '
$sSearchFor = [Microsoft.VisualBasic.Interaction]::InputBox($sMsg, $sTitle)
$bDoSearch = -Not ([string]::IsNullOrEmpty($sSearchFor) -Or [string]::IsNullOrWhitespace($sSearchFor))

If ( [string]::IsNullOrEmpty($sEmailAddress) -Or [string]::IsNullOrWhitespace($sEmailAddress) ) {
	Write-Output ("** ERROR - No email address(es) given. Aborting.")
} Else {
	Write-Output ("** EXO mailbox(es) given: {0}" -f $sEmailAddress)
	If ( $bDoSearch ) {
		Write-Output ("** Search string(s) given: {0}" -f $sSearchFor)
	}
	
	# Connect to Exchange Online using official Exchange Online Powershell Module
	Write-Output ("** Connecting to Exchange Online using the API from the official Exchange Online Powershell Module...")
	$EXOSession = New-ExoPSSession -ErrorAction Stop
	Import-PSSession $EXOSession -AllowClobber
	
	Write-Output ("** Searching mailbox configurations in EXO...")
	ForEach ($email in $sEmailAddress) {
		# Query Exchange Online
		$sBlockedSenders = Get-MailboxJunkEmailConfiguration -Identity $email | Select -ExpandProperty BlockedSendersAndDomains
		# Double-check if blocklist is empty (will still come up as count 1 otherwise, likely due to how the returned object works)
		If ( [string]::IsNullOrEmpty($sBlockedSenders) -Or [string]::IsNullOrWhitespace($sBlockedSenders) ) {
			Write-Output("** EXO Mailbox: {0} | BlockedSendersAndDomains Count: {1} **" -f $email, "0 (Empty)")
		} Else {
			$iBlockedSenderCount = $sBlockedSenders | Measure | Select -ExpandProperty Count
			Write-Output("** EXO Mailbox: {0} | BlockedSendersAndDomains Count: {1} **" -f $email, $iBlockedSenderCount)
			# We're either searching for a string or just outputting all the blocked senders
			If ( -Not $bDoSearch ) {
				Write-Output( $sBlockedSenders )
			} Else {
				$bFound = $FALSE
				ForEach ( $senderEmail in $sSearchFor ) {
					$sFoundString = $sBlockedSenders | Select-String $senderEmail
					If ( -Not ( [string]::IsNullOrEmpty($sFoundString) -Or [string]::IsNullOrWhitespace($sFoundString) ) ) {
						Write-Output( "** FOUND {0} in block list of EXO mailbox {1}" -f $sFoundString, $email )
						$bFound = $TRUE
					} # end if
				} # end foreach
				If ( -Not $bFound ) {
					Write-Output( "** Search strings not found for mailbox $email")
				} # end if
			} # end if
		} # end if
	} # end foreach
	
	Remove-PSSession $EXOSession
} # end if
	
# Pause until a key is pressed
Write-Output ("Done. Press any key to continue...")
$HOST.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | OUT-NULL
$HOST.UI.RawUI.Flushinputbuffer()
