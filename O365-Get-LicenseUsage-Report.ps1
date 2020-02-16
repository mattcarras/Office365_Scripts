# Export O365 license usage report to CSV
# Code tweaked from various sources
# Last Updated: 2-16-20 Matt Carras

$sCSVFile = "C:\TEMP\O365_ExportLicenseUsage.csv"
Write-Output ("** Output CSV file: {0}" -f $sCSVFile)
Import-Module MSOnline
Connect-MsolService
Get-MsolUser -All | Where {$_.IsLicensed -eq $true} | Select DisplayName,@{n='Licenses Type';e={$_.Licenses.AccountSKUid}} | Export-CSV -Path $sCSVFile -notype
