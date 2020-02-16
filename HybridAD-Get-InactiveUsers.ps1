# Gets last login date from mailbox in EXO for hybrid environments where some users with on-prem AD may only login to O365
# Only gets enabled users with expiring passwords
# NOTE: Run from Microsoft Exchange Online Powershell Module shell
# Last Updated: 12-2-19 Matt Carras
Write-Output('** NOTE: Make sure you are running from the Exchange Online Powershell Module shell')

Connect-EXOPSSession

$LastLogonDate = @{
    Name = 'LastLogonDate'
	Expression = { If ( -Not ([string]::IsNullOrEmpty($_.EmailAddress) -Or [string]::IsNullOrWhitespace($_.EmailAddress) ) ) {
		Get-MailboxStatistics -Identity $_.EmailAddress | Select -ExpandProperty LastLogonTime
		} Else {
			$_.LastLogonDate
		}
	}
}

Write-Output('** Collecting information from AD and EXO...')
Get-ADUser -Filter {Enabled -eq $TRUE -and PasswordNeverExpires -ne $TRUE} -Properties Name,SamAccountName,EmailAddress,LastLogonDate | Where {($_.LastLogonDate -lt (Get-Date).AddDays(-90)) -or ($_.LastLogonDate -eq $NULL)} | Select Name,SamAccountName,EmailAddress,$LastLogonDate | Where {($_.LastLogonDate -lt (Get-Date).AddDays(-90)) -or ($_.LastLogonDate -eq $NULL)}