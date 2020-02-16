# Export folders to CSV for SharePoint Migration
# Shouldn't be needed anymore with newest version of official SharePoint Migration Tool (SPMT)
# Last Updated: 2-16-20 Matt Carras

## START REQUIRED CONFIGURATION ## 
$sDefaultSharepointSiteTarget="https://contoso-my.sharepoint.com/personal" # Default upload target
## END REQUIRED CONFIGURATION ##

## START OPTIONAL CONFIGURATION ##
$sCSVHeader="Source,SourceDocLib,SourceSubFolder,TargetWeb,TargetDocLib,TargetSubFolder"
$sTargetDocLib="Documents"
$sCSVFile="C:\TEMP\SharePoint_Migration_Batch.csv"
## END OPTIONAL CONFIGURATION ##

Function Get-Folder($initialDirectory)
{
    [void][Reflection.Assembly]::LoadWithPartialName("System.windows.forms")

    $foldername = New-Object System.Windows.Forms.FolderBrowserDialog
    $foldername.Description = "Select a folder to migrate"
    $foldername.rootfolder = "MyComputer"
	
    if($foldername.ShowDialog() -eq "OK")
    {
        $folder = $foldername.SelectedPath
    }
    return $folder
} # end function

Write-Output ("** Output CSV file: {0}" -f $sCSVFile)

$sSource = Get-Folder

# Load VB assembly for InputBox
[void][Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic')
$sTitle = 'Enter Sharepoint Site or OneDrive site target'
$sMsg = "Please enter URL for the SharePoint or OneDrive site to upload to (Example: $sDefaultSharepointSiteTarget/mcarras_contoso_com/)"
$sSharepointSiteTarget = [Microsoft.VisualBasic.Interaction]::InputBox($sMsg, $sTitle, $sDefaultSharepointSiteTarget + '/')

# Recreate CSV file if it already exists
if (Test-Path $sCSVFile) { Remove-Item $sCSVFile }
Add-Content -Path $sCSVFile -Value $sCSVHeader
Get-ChildItem -Recurse -Directory $sSource | Select FullName | foreach { 
	$sRelPath = $_.FullName.Replace("$sSource\",'')
	$sAbsPath = $_ | Select -Expand FullName
	Add-Content -Path $sCSVFile -Value "`'$sAbsPath`','','','',`'$sSharepointSiteTarget`',`'$sTargetDocLib`',`'$sRelPath`'"
} # end foreach
