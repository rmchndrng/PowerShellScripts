Param
(
    [Parameter(Mandatory = $false)]    
    [String]$DatabasesFile = ".\databases.config",
    [Parameter(Mandatory = $false)]    
    [String]$BackupFolderPath = "c:\temp\dbbackups",
    [Parameter(Mandatory = $false)]    
    [String]$Prefix,
    [Parameter(Mandatory = $false)]    
    [String]$Suffix,
    [Parameter(Mandatory = $false)]    
    [Boolean]$ApplyPrefix = $false,
    [Parameter(Mandatory = $false)]    
    [Boolean]$ApplySuffix = $false,
    [Parameter(Mandatory = $false)]    
    [Boolean]$ReplaceDatabase = $false,
    [Parameter(Mandatory = $false)]    
    [Boolean]$Confirm = $true,
    [Parameter(Mandatory = $false)]    
    [Boolean]$DeleteBackups = $false,
    [Parameter(Mandatory = $false)]    
    [Boolean]$Zip = $true
)

#If you get an access denied error, Pls make sure the account under which the SQL server service is 
#running has sufficient permissions to the backup location.
#The backup is running on the server mentioned, not on this computer
#https://docs.microsoft.com/en-us/powershell/sqlserver/sqlserver/vlatest/backup-sqldatabase
#https://docs.microsoft.com/en-us/powershell/sqlserver/sqlserver/vlatest/restore-sqldatabase
#http://powershelldiaries.blogspot.in/2015/08/backup-sqldatabase-restore-sqldatabase.html
$TempArray = @()
$TempArray = $env:PSModulePath -split ';'
# 110 for SQL 2012, 120 for SQL 2014, 130 for SQL 2016
$env:PSModulePath = ($TempArray -notmatch '110') -join ';'

if (Get-Module -ListAvailable -Name SQLPS) {
    Write-Host "SQLPS Module exists"
}
else {
    Import-Module SQLPS -DisableNameChecking
}

function _RestoreDatabase([string] $targetServerName, [string]  $targetDbname, [string]  $backupFileName, [string]  $replaceDatabase, [string]  $confirm, [Microsoft.SqlServer.Management.Smo.RelocateFile[]]  $relocate) {
    Write-Host "[Restore]ServerInstance:$targetServerName Database:$targetDbname BackupFile:$backupFileName"; 
    if ($replaceDatabase -eq $true) {
        if ($confirm -eq $true) {                
            Restore-SqlDatabase -ServerInstance $targetServerName -Database $targetDbname -BackupFile $backupFileName -ReplaceDatabase -Confirm -RelocateFile $relocate
        }
        else {
            Restore-SqlDatabase -ServerInstance $targetServerName -Database $targetDbname -BackupFile $backupFileName -ReplaceDatabase -RelocateFile $relocate
        }
    }
    else {
        if ($confirm -eq $true) {
            Restore-SqlDatabase -ServerInstance $targetServerName -Database $targetDbname -BackupFile $backupFileName -Confirm -RelocateFile $relocate
        }
        else {
            Restore-SqlDatabase -ServerInstance $targetServerName -Database $targetDbname -BackupFile $backupFileName -RelocateFile $relocate
        }
    }
}

#Function to create the RelocateFile object from a backup file (LogicalName,PhysicalPath)
function _GetRelocateFile([string]$targetServerName, [string]$backupFileName, [string]$logFilePath, [string] $dataFilePath) {
    #http://www.mikefal.net/2017/01/25/using-powershell-to-restore-to-a-new-location/   
    #Get a list of database files in the backup
    $dbfiles = Invoke-Sqlcmd -ServerInstance $targetServerName -Database tempdb -Query "RESTORE FILELISTONLY FROM DISK='$backupFileName';"  
    $relocate = @()
    
    #Loop through filelist files, replace old paths with new paths
    foreach ($dbfile in $dbfiles) {
        $DbFileName = $dbfile.PhysicalName | Split-Path -Leaf
        if ($dbfile.Type -eq 'L') {
            $newfile = $logFilePath
        }
        else {
            $newfile = $dataFilePath
        }
        $relocate += New-Object Microsoft.SqlServer.Management.Smo.RelocateFile ($dbfile.LogicalName, $newfile)
    }
   
    return $relocate;
}


$ErrorActionPreference = "Stop"

$ret = @()

Write-Host "Parameters:"
Write-Host "DatabasesFile:"$DatabasesFile
Write-Host "BackupFolderPath:"$BackupFolderPath
Write-Host "Prefix"$Prefix
Write-Host "Suffix:"$Suffix

$dt = Get-Date -Format yyyyMMddHHmmss
$endsWithSlash = $BackupFolderPath.EndsWith("\")
Write-Host "endswith"$endsWithSlash
if ($endsWithSlash -ne $true) {
    $BackupFolderPath = $BackupFolderPath + "\";
    Write-Host $BackupFolderPath
}
$BackupFolderPath = $BackupFolderPath + $dt
if (-Not (Test-Path $BackupFolderPath)) {
    mkdir -path $BackupFolderPath
}

[xml]$deploymentSettings = get-content -Path $DatabasesFile;

$databases = $deploymentSettings.SelectNodes("//database");
$index = 0;
$databases | ForEach-Object {
    $index = $index + 1;
    $sourceServerName = $_.source.'server-name'
    $sourceDbname = $_.source.'database-name'
    $backupFileName = $BackupFolderPath + "\" + $Prefix + $sourceDbname + $Suffix + "_" + $index + ".bak";
    Write-Host $backupFileName    
    Write-Host "[Backup]ServerInstance:$sourceServerName Database:$sourceDbname BackupFile:$backupFileName"; 
    try {        
        Backup-SqlDatabase -ServerInstance $sourceServerName -Database $sourceDbname -BackupFile $backupFileName
        Write-Host "Backup generated successfully";
        $dbInfo = New-Object -TypeName System.Object
        $dbInfo | Add-Member SourceServerName $sourceServerName
        $dbInfo | Add-Member SourceDatabase $sourceDbname
        $dbInfo | Add-Member BackupFile $backupFileName
        $target = $_.target;
        try {
            if ($target -ne $null) {
                $targetServerName = $target.'server-name'
                if ($targetServerName -eq $null -or $targetServerName -eq "") {
                    $targetServerName = $sourceServerName
                }
                $targetDbname = $target.'database-name'
                if ($targetDbname -eq $null -or $targetDbname -eq "") {
                    $targetDbname = $sourceDbname
                }
                if ($ApplyPrefix -eq $true) {
                    $targetDbname = $Prefix + $targetDbname;
                }
                if ($ApplySuffix -eq $true) {
                    $targetDbname = $targetDbname + $Suffix;
                }
                
                #http://sqlblog.com/blogs/allen_white/archive/2009/02/19/finding-your-default-file-locations-in-smo.aspx
                #Identifying the default locations of the SQL server data files on the target server
                $filePrefix = $targetDbname + $dt;
                $dataPhysicalFileName = $filePrefix + "_Data";
                $logPhysicalFileName = $filePrefix + "_Log";

                $s = new-object ('Microsoft.SqlServer.Management.Smo.Server') $targetServerName
                $fileloc = $s.Settings.DefaultFile
                $logloc = $s.Settings.DefaultLog
                if ($fileloc.Length -eq 0) {
                    $fileloc = $s.Information.MasterDBPath
                }
                if ($logloc.Length -eq 0) {
                    $logloc = $s.Information.MasterDBLogPath
                }

                $dataFilePath = $fileloc + $dataPhysicalFileName + ".mdf";
                $logFilePath = $logloc + $logPhysicalFileName + ".mdf";
                $relocate = @()
                $relocate = _GetRelocateFile -targetServerName $targetServerName -backupFileName $backupFileName -logFilePath $logFilePath -dataFilePath $dataFilePath            
              
                _RestoreDatabase -targetServerName $targetServerName -targetDbname $targetDbname -backupFileName $backupFileName -replaceDatabase $ReplaceDatabase -confirm $Confirm -relocate $relocate
                
                Write-Host "Database restored successfully";   
                $dbInfo | Add-Member TargetServerName $targetServerName
                $dbInfo | Add-Member TargetDatabase $targetDbname       
                $dbInfo | Add-Member TargetDatabaseDataFile $dataFilePath       
                $dbInfo | Add-Member TargetDatabaseLogFile $logFilePath                        
            }
        }        
        finally {
            $ret = $ret + $dbInfo;
        }               
    }  
    catch {
        Write-Host "Error occured, unable to generate the backup!!!"
        Write-Host "Messge:$_.Exception.Message"       
    }    
}
if ($DeleteBackups -eq $true) {
    Remove-item $BackupFolderPath -Recurse -Force
}
else {
    if ($Zip -eq "true") {    
        $zipSource = $BackupFolderPath
        $zipDestination = "$BackupFolderPath.zip"
        If (Test-path $zipDestination) {Remove-item $zipDestination}
        Add-Type -assembly "system.io.compression.filesystem"
        [io.compression.zipfile]::CreateFromDirectory($zipSource, $zipDestination)
        Remove-item $BackupFolderPath -Recurse -Force
    }
}
return $ret;