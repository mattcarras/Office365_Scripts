<#  
.SYNOPSIS   
	Performs common re-onboarding tasks on an account that has been offboarded.
         
.DESCRIPTION   
	Performs common re-onboarding tasks on an account that has been offboarded, in both hybrid and regular Office 365 environments.
	Requires MSOnline and Exchange Online Powershell modules.
	
	Can perform these tasks:
	- On-Prem / Azure AD: Re-enable account, reset password, and move to different OU.
	- On-Prem Exchange / Exchange Online: Show mailbox in GAL.
	- Hybrid AD / Exchange: Sync changes using AD Connect Sync.
	- Exchange Online: Convert mailbox back to user mailbox and remove any forwarding.
	- Azure AD / Office 365: Add given licenses.
	- OneDrive: Remove site collection administrator access / delegation.
	
	.PARAMETER TargetUPN
        String. Required. UserPrincipalName of target user to re-onboard. This is the only required parameter.
	
	.PARAMETER HybridAD
		Switch. If given, enable and reset accounts with on-prem AD instead of Azure AD.
	
	.PARAMETER OnPremExchangeServer
		String. Computer name for on-prem Exchange Server in hybrid Exchange environments. Currently used only to hide mailbox from GAL.
		
	.PARAMETER ADConnectSyncServer
		String. Computer name for the server which contains AD Connect Sync in hybrid AD / Exchange environments.
		
	.PARAMETER PromptForCred
		Switch. If given, prompt for the credentials for on-prem AD and Exchange instead of using the current user's credentials.
		
	.PARAMETER EXOAdminUPN
		String. Exchange Online Admin UserPrincipalName. If this is left blank or doesn't match the one entered into the prompt for connecting to Azure AD through MSOnline you'll get a second prompt for connecting to Exchange Online.
	
	.PARAMETER AddLicenses
		Strings. Licenses to add in O365 / Microsoft Online. Example: -AddLicenses "costo:ATP_ENTERPRISE","costo:ENTERPRISEPACK"
		
	.PARAMETER NewADPW
		String. Plain-text password to use for resetting the password in AD or Azure AD.
		
	.PARAMETER MoveToOU
		String. Full distinguished name for the target OU to move the re-enabled user to. On-prem / hybrid AD only.
		
	.PARAMETER RemoveMailboxForwarding
		Switch. If enabled, disable any forwarding on the mailbox.
	
	.PARAMETER TenantName
		String. Office 365 / Azure AD Tenant Name required for connecting to Sharepoint Online Admin to interact with OneDrive and Sharepoint Online.
	
	.PARAMETER RemoveODAdmin
		String. Remove given UPN as a site collection administrator to the target UPN's OneDrive site, removing their access to it.
		
	.NOTES   
        Author: Matthew Carras
		Last Updated: 3-27-20
#>    
Param (
	# Target UserPrincipalName
	[Parameter(Mandatory = $true)]
	[Alias("UPN","UserPrincipalName")]
	[string] $TargetUPN,
	
	# We have a Hybrid AD setup
	[Parameter(Mandatory = $false)]
	[Switch] $HybridAD,
	
	# Prompt for on-prem AD and Exchange credentials
	[Parameter(Mandatory = $false)]
	[Alias("PromptForCredentials")]
	[Switch] $PromptForCred,
	
	# Server name for on-prem Exchange that allows remote exchange powershell
	[Parameter(Mandatory = $false)]
	[string] $OnPremExchangeServer,
	
	# Server name for server running AD Connect Sync that allows remote powershell
	[Parameter(Mandatory = $false)]
	[string] $ADConnectSyncServer,
	
	# Admin UPN for accessing Exchange Online. If not given, will prompt twice
	[Parameter(Mandatory = $false)]
	[Alias("EXOAdminUserPrincipalName")]
	[string] $EXOAdminUPN,
	
	# 365 / Microsoft Online licenses to add
	[Parameter(Mandatory = $false)]
	[string[]] $AddLicenses,
	
	# New password for AD
	[Parameter(Mandatory = $false)]
	[Alias("NewADPassword")]
	[string] $NewADPW,

	# Move user object to given OU (hybrid AD only)
	[Parameter(Mandatory = $false)]
	[string] $MoveToOU,
	
	# Remove any forwarding setup on the mailbox
	[Parameter(Mandatory = $false)]
	[switch] $RemoveMailboxForwarding,
	
	#Remove any delegation setup on the mailbox
	# [Parameter(Mandatory = $false)]
	# [switch] $RemoveMailboxDelegation
	
	# Tenant name for OneDrive/Sharepoint admin URL
	[Parameter(Mandatory = $false)]
	[Alias("SPOTenantName")]
	[string] $TenantName,
	
	# User to remove OneDrive access from
	[Parameter(Mandatory = $false)]
	[string] $RemoveODAdmin
) #end param

Function IsNullEmptyOrWhitespace( $str ) {
	return ([string]::IsNullOrEmpty($str) -Or [string]::IsNullOrWhitespace($str))
} #end function

#Import MSOnline Module
Import-Module MSOnline
 
#Import Exchange Online Module
Import-Module $((Get-ChildItem -Path $($env:LOCALAPPDATA + "\Apps\2.0\") -Filter Microsoft.Exchange.Management.ExoPowershellModule.dll -Recurse).FullName | ?{ $_ -notmatch "_none_" } | select -First 1)

$CredSplat = @{ } # Given to all commands that require on-prem credentials
If ( $PromptForCred ) {
	$cred = Get-Credential -Message "Enter admin credentials for on-prem AD and Exchange"
	Write-Verbose ("Using given credentials for on-prem admin user [{0}]" -f $cred.Username)
	$CredSplat.Add('Credential', $cred)
} #end if

# Initially set mailbox to be same as given user UPN
$sMailbox = $TargetUPN

# -- On-Prem / Hybrid AD --
If ( $HybridAD ) {
	Write-Output ("*** Working within on-prem AD for {0}..." -f $TargetUPN)
	# Get AD User object and grab registered primary email address
	$adUser = Get-ADUser -Filter{UserPrincipalName -eq $TargetUPN} -Properties EmailAddress @CredSplat
	$sMailbox = $adUser | Select -ExpandProperty EmailAddress
	
	# Disable account
	Write-Output ("*** Enable AD account {0} in on-prem AD..." -f $TargetUPN)
	Enable-ADAccount -Identity $adUser @CredSplat

	# Reset password, if given
	If ( ! (IsNullEmptyOrWhiteSpace($NewADPW)) ) {
		Write-Output ("*** Resetting PW for {0} to given password in on-prem AD..." -f $TargetUPN)
		Set-ADAccountPassword -Identity $adUser -Reset -NewPassword (ConvertTo-SecureString -AsPlainText $NewADPW -Force) @CredSplat
	} #end if (reset password)
	
	# Move to OU, if given
	If ( ! (IsNullEmptyOrWhiteSpace($MoveToOU)) ) {
		Write-Output ("*** Moving {0} to {1} in on-prem AD..." -f $TargetUPN,$MoveToOU)
		Move-ADObject -Identity $adUser -TargetPath $MoveToOU @CredSplat
	} #end if
} #end if (hybrid AD)

# -- On-Prem / Hybrid Exchange --
If ( ! (IsNullEmptyOrWhiteSpace($OnPremExchangeServer)) ) {
	# Attempt to connect to the on-prem Exchange server to set the mailbox hidden from GAL
	Write-Output ("*** Connecting to on-prem Exchange server [{0}]" -f $OnPremExchangeServer)
	$PSSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri "http://$OnPremExchangeServer/PowerShell/" -Authentication Kerberos @CredSplat
	Import-PSSession $PSSession -DisableNameChecking 

	Write-Output ("*** Setting mailbox [{0}] to be shown in GAL in on-prem Exchange..." -f $sMailbox)
	Set-RemoteMailbox -Identity $sMailbox -HiddenFromAddressListsEnabled $false

	Write-Output ("*** Exiting on-prem Exchange remote session...")
	Remove-PSSession $PSSession
} #end if (on-prem exchange)

# -- Synchronize changes using AD Connect Sync, if server given --
If ( ! (IsNullEmptyOrWhiteSpace($ADConnectSyncServer)) ) {
	# Forces a sync with Azure AD on the server running AD Connect Sync
	# Requires specific permissions assigned to the user
	Write-Output("*** Attempting to perform a sync using AD Connect Sync...If you get an error below make sure the server is correct, it has WinRM ports open and PSRemoting enabled, and that the given credentials (if given) have the correct permissions to perform an ADSyncSync")
	Invoke-Command -ComputerName $ADConnectSyncServer -ScriptBlock { Start-ADSyncSyncCycle -PolicyType Delta } @CredSplat
} #end if
	
# -- Azure AD (Msol) and Exchange Online --
If ( ! (IsNullEmptyOrWhiteSpace($EXOAdminUPN) ) ) {
	Write-Output ("*** Connecting to Azure AD (Msol) and Exchange Online using admin UPN [{0}]..." -f $EXOAdminUPN)
	Connect-MsolService
	$EXOSession = New-ExoPSSession -UserPrincipalName $EXOAdminUPN
} Else {
	Write-Output ("*** Connecting to Azure AD (Msol) and Exchange Online...")
	Connect-MsolService
	$EXOSession = New-ExoPSSession
} #end if (adminUPN given)

# Import EXO session. Make sure to remove session later!
Import-PSSession $EXOSession -AllowClobber

# Convert mailbox back to a regular user mailbox
Write-Output ("*** Converting {0} back to Regular in Exchange Online..." -f $sMailbox)
Set-Mailbox $sMailbox -Type Regular

# Remove any forwarding, if given
If ( $RemoveMailboxForwarding ) {
	Write-Output ("*** Disabling forwarding for [{0}] in Exchange Online..." -f $sMailbox)
	Set-Mailbox -Identity $sMailbox -DeliverToMailboxAndForward $false
} #end if

<#
# Add full and send-as delegation, if given
If ( ! (IsNullEmptyOrWhiteSpace($DelegateMailboxTo)) ) {
	Add-MailboxPermission -Identity $sMailbox -User $DelegateMailboxTo.Address -AccessRights FullAccess -InheritanceType All
	Add-RecipientPermission -Identity $sMailbox -AccessRights SendAs -Trustee $DelegateMailboxTo.Address
} #end if
#>

# If not using hybrid Exchange, add back to GAL here
If ( IsNullEmptyOrWhiteSpace($OnPremExchangeServer) ) {
	Write-Output ("*** Adding {0} back to GAL in Exchange Online..." -f $sMailbox)
	Set-Mailbox -Identity $sMailbox -HiddenFromAddressListsEnabled $false
} #end if (non-hybrid Exchange)

# If not using hybrid AD, enable access and reset password here
If ( ! $HybridAD ) {
	# Disable account
	Write-Output ("*** Re-enabling {0} in Azure AD / Office 365..." -f $TargetUPN)
	Set-MsolUser -UserPrincipalName $TargetUPN -BlockCredential $false
	
	# Reset password, if given
	If ( ! (IsNullEmptyOrWhiteSpace($NewADPW)) ) {
		Write-Output ("*** Resetting password for {0} to given password in Azure AD / Office 365..." -f $TargetUPN)
		Set-MsolUserPassword -UserPrincipalName $TargetUPN -NewPassword $NewADPW
	} #end if
} #end if (non-hybrid AD)
	
# Add given licenses
If ( ! (IsNullEmptyOrWhiteSpace($AddLicenses) ) ) {
	Write-Output ("***Adding given licenses to {0} in Azure AD / Office 365..." -f $TargetUPN)
	Set-MsolUserLicense -UserPrincipalName $TargetUPN -AddLicenses $AddLicenses
} #end if

Write-Output ("*** Exiting Exchange Online session...")
Remove-PSSession $EXOSession

# -- OneDrive / Sharepoint --
# Optional: If user and tenant name is given, remove access to target UPN's OneDrive
If ( ! (IsNullEmptyOrWhiteSpace($RemoveODAdmin)) -And ! (IsNullEmptyOrWhiteSpace($TenantName)) ) {
	Import-Module Microsoft.Online.SharePoint.PowerShell -DisableNameChecking
	
	Write-Output ("*** Connecting to Sharepoint/OneDrive admin URL for tenant [$TenantName]...")
	Connect-SPOService -Url "https://$TenantName-admin.sharepoint.com"

	# Get user's OneDrive site. TODO: Filter by alias
	$sODSite = Get-SPOSite -IncludePersonalSite $true -Filter "Owner -eq $TargetUPN -and Url -like '-my.sharepoint.com/personal/'" | Select -ExpandProperty URL | Select -First 1

	Write-Output ("*** Removing [{0}] as a site collection admin for [{1}]..." -f $RemoveODAdmin,$sODSite)
	Set-SPOUser -Site $sODSite -LoginName $RemoveODAdmin -IsSiteCollectionAdmin $false

	Write-Output ("*** Disconnecting from Sharepoint/OneDrive admin...")
	Disconnect-SPOService
} #end if (onedrive and sharepoint)

# Pause until a key is pressed
Write-Output ("Done. Press any key to continue...")
$HOST.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | OUT-NULL
$HOST.UI.RawUI.Flushinputbuffer()
