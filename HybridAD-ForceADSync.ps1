$adconnectserver = 'example.conso.com'
$cred = Get-Credential -Message "Enter credentials with permissions for AD Connect Sync: "

Write-Output("** If you get an error below make sure you the server is correct, it has WinRM ports open and PSRemoting enabled, and that you have the correct permissions to perform an ADSyncSync (same as the user setup for the AD Connect service)")
Invoke-Command -ComputerName $adconnectserver -ScriptBlock { Start-ADSyncSyncCycle -PolicyType Delta } -Credential $cred
