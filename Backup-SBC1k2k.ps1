#region INFO
<# 
.SYNOPSIS
 
    Backup-SBC1k2k.ps1 creates backups for Ribbon (previously Sonus) SBC1000 & SBC2000 devices using PowerShell
 
.DESCRIPTION
    Author: Andrew Morpeth
    Contact: https://ucgeek.co/
    More info: https://ucgeek.co/2015/01/backup-sonus-sbc-1k2k-using-powershell-and-rest-api/
    Download: https://github.com/ucgeek/Backup-SBC1k2k
    
    Creates backups for Ribbon (previously Sonus) SBC1000 & SBC2000 devices using PowerShell.
.RUN INSTRUCTIONS 
    Update the settings below to suit your environment:
    $Gateways is a key/value pair - key=name, value=sbcFQDN e.g. "SBC01" = "sbc01.domain.com";
    $BackupFolder = path to save backup ending with \ e.g. "C:\SfBBackup\SBC\"
    $BackupsDaysToKeep = numbers of days to keep backup files
    $Username / $Password = a user with 'rest' level access created in the SBC - https://support.sonus.net/display/UXDOC61/Permissions+Overview
    You can automate the script using a scheduled task on a server that has access to the SBC IP. Use PowerShell.exe. with the following arguments: '-command "& '<PATH>\Backup-SBC1k2k.ps1'"
.NOTES
    v1.0 - Initial release
    v1.1 - TLS changes    
#>
#endregion INFO

#region Settings
$Gateways = @{
    "SBC01" = "sbc01.domain.com";
    "SBC02" = "sbc02.domain.com";
}

$BackupFolder = "C:\SfBBackup\SBC\" #Make sure you use an SBC only backup location as the script will delete old backups
$BackupsDaysToKeep = "14" #days to keep backups
$Username = "rest"
$Password = "backmeup!@!" #Create secure hash if required
#endregion Settings

$BackupDate = (Get-Date).ToString("yyyy.mm.dd-hh.mm.ss")

#Clean up old backups
if(!(Test-Path -Path $BackupFolder))
{
    Write-Output "$BackupFolder not found, nothing to delete"
}
else
{
    Write-Output "Cleaning old backups from $BackupFolder older than $BackupsDaysToKeep day(s)"
    $CurrentDate = Get-Date
    $DatetoDelete = $CurrentDate.AddDays("-$BackupsDaysToKeep")
    Get-ChildItem $BackupFolder -recurse | Where-Object { $_.LastWriteTime -lt $DatetoDelete } | Remove-Item -force -Recurse | Out-Null
}

foreach ($gateway in $Gateways.Keys)
{
    $Name = $gateway
    $IP = $Gateways.$Name

    Write-Output "Backing up $name"

    #Variables
    $BackupPath = $BackupFolder + $Name + " - " + $IP + " - " + $BackupDate + ".tar"

    #Authenticate to SBC
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $LoginUrl = "https://" + $IP + "/rest/login"
    $LoginCredentials = "Username=" + $Username + "&Password=" + $Password

    Invoke-RestMethod -Uri $LoginUrl -Method Post -Body $LoginCredentials -SessionVariable ps -Verbose

    #Backup Gateways
    $args = ""
    $BackupUrl = "https://" + $IP + "/rest/system?action=backup"
    Invoke-RestMethod -Uri $BackupUrl -Method POST -Body $args -WebSession $ps -OutFile $BackupPath
}
