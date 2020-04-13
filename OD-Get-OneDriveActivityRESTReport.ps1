# Report on OneDrive activity in last 14 days using REST API
# Functions taken from: https://www.altitude365.com/2018/09/23/retrieve-and-analyze-office-365-usage-data-with-powershell-and-microsoft-graph-api/
# TODO: Add client-side authentication without needing a registered app ID
# 4-13-20 MattC

function Get-GraphApi {
 param (
	 [parameter(Mandatory=$true)]
	 $ClientID,

	[parameter(Mandatory=$true)]
	 $ClientSecret,

	[parameter(Mandatory=$true)]
	 $TenantName,

	[parameter(Mandatory=$true)]
	 $Url
 )


 # Graph API URLs.
 $LoginUrl = "https://login.microsoft.com"
 $RresourceUrl = "https://graph.microsoft.com"
 
 
 # Compose REST request.
 $Body = @{ grant_type = "client_credentials"; resource = $RresourceUrl; client_id = $ClientID; client_secret = $ClientSecret }
 $OAuth = Invoke-RestMethod -Method Post -Uri $LoginUrl/$TenantName/oauth2/token?api-version=1.0 -Body $Body
 
 # Check if authentication is successfull.
 if ($OAuth.access_token -eq $null)
 {
 Write-Error "No Access Token"
 }
 else
 {
 # Perform REST call.
 $HeaderParams = @{ 'Authorization' = "$($OAuth.token_type) $($OAuth.access_token)" }
 $Result = (Invoke-WebRequest -UseBasicParsing -Headers $HeaderParams -Uri $Url)

# Return result.
 $Result
 }
}

function Get-UsageReportData {
 param (
	 [parameter(Mandatory = $true)]
	 [string]$ClientID,

	[parameter(Mandatory = $true)]
	 [string]$ClientSecret,

	[parameter(Mandatory = $true)]
	 [string]$TenantName,
	 
	[parameter(Mandatory=$true)]
	 $GraphUrl
 )

try {
 # Call Microsoft Graph and extract CSV content and convert data to PowerShell objects.
 $result = Get-GraphApi -ClientID $ClientID -ClientSecret $ClientSecret -TenantName $TenantName -Url $GraphUrl
 #$result
 ($result.RawContent -split "\?\?\?")[1] | ConvertFrom-Csv
 }
 catch {
  Write-Error "Bad results from Get-GraphAPI"
 }
}

$ClientID = "CLIENT ID GOES HERE" # You registered apps App ID.
$ClientSecret = "CLIENT SECRET GOES HERE" # Your registered apps key.
$TenantName = "contoso.onmicrosoft.com" # Your full tenant name.
$GraphUrl = "https://graph.microsoft.com/v1.0/reports/getOneDriveActivityUserDetail(period='D7')" # The Graph URL to retrieve data.

$UsageData = Get-UsageReportData -ClientID $ClientID -ClientSecret $ClientSecret -TenantName $TenantName -GraphUrl $GraphUrl

# Loop through usage data to find enabled users with no activity in last 14 days
$UsageData | ForEach { 
	$usage = $_
	$IsDeleted = $usage | Select -ExpandProperty 'Is Deleted'
	$LastActivityDate = $usage | Select -ExpandProperty 'Last Activity Date'
	$UPN = $usage | Select -ExpandProperty 'User Principal Name'
	If ( $IsDeleted -ne "True" -And -Not [string]::IsNullOrEmpty($LastActivityDate) -And -Not [string]::IsNullOrEmpty($UPN) ) {
		$User = Get-ADUser -Filter {Enabled -eq $TRUE -and UserPrincipalName -eq $UPN} -Properties Name,SamAccountName,EmailAddress,LastLogonDate,PasswordLastSet
		If ($User -And -Not $User.LastLogonDate -lt (Get-Date).AddDays(-14) -And [datetime]::ParseExact($LastActivityDate, "yyyy-MM-dd", $null) -lt (Get-Date).AddDays(-14)) {
			Write-Output( "$UPN has no activity for over 14 days. Last active: $LastActivityDate, Last AD Login: " + $User.LastLogonDate)
		}
	}
}
