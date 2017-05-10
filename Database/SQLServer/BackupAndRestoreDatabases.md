# Backup and Restore SQL Server databases

Usage

.\BackupAndRestoreDatabase.ps1 
    -DatabasesFile "\\network-machine\c$\temp\databases.config" 
    -BackupFolderPath "\\network-machine\c$\temp"
    -ReplaceDatabase $true
    -DeleteBackups $true

## Parameters


### -DatabasesFile

    * An xml file containing the definitions of the source and target databases.
    * Datatype - [string]
    * Mandatory - No
    * Default value - ".\databases.config"


### -BackupFolderPath

    * Path to the folder where the backup (.bak) files will be generated. 
    (Make sure the user account under which the server service is running has enough 
    permission to write to this path.)
    * Datatype - [string]
    * Mandatory - No
    * Default value - "c:\temp"

### -Prefix

    * Text which should be prefixed to the backup file name and the database being restored.
    * Datatype - [string]
    * Mandatory - No
    * Default value - ""

### -Suffix

    * Text which should be appended to the backup file name and the database being restored.
    * Datatype - [string]
    * Mandatory - No
    * Default value - ""

### -ApplyPrefix

    * Flag which decides whether to add the prefix to the database name
    * Datatype - [bool]
    * Mandatory - No
    * Default value - $false

### -ApplySuffix

    * Flag which decides whether to add the suffix to the database name
    * Datatype - [bool]
    * Mandatory - No
    * Default value - $false

### -ReplaceDatabase

    * Flag to force the script to replace the database if already exists on the target server.
    * Datatype - [bool]
    * Mandatory - No
    * Default value - $false

### -Confirm

    * Flag to force the script not to ask for confirmation when creating or replacing the database on the target server.
    * Datatype - [bool]
    * Mandatory - No
    * Default value - $true

### -DeleteBackups

    * Flag to delete all the backups after restoring the databases on the target server
    * Datatype - [bool]
    * Mandatory - No
    * Default value - $false

### -Zip

    * Flag to zip the folder which contains the backup
    * Datatype - [bool]
    * Mandatory - No
    * Default value - $true

Can use the script just for taking backups by omitting the target nodes in the databases.config xml file.

References:

* [https://docs.microsoft.com/en-us/powershell/sqlserver/sqlserver/vlatest/backup-sqldatabase](https://docs.microsoft.com/en-us/powershell/sqlserver/sqlserver/vlatest/backup-sqldatabase)
* [https://docs.microsoft.com/en-us/powershell/sqlserver/sqlserver/vlatest/restore-sqldatabase](ttps://docs.microsoft.com/en-us/powershell/sqlserver/sqlserver/vlatest/restore-sqldatabase)
* [http://powershelldiaries.blogspot.in/2015/08/backup-sqldatabase-restore-sqldatabase.html](http://powershelldiaries.blogspot.in/2015/08/backup-sqldatabase-restore-sqldatabase.html)
* [http://www.mikefal.net/2017/01/25/using-powershell-to-restore-to-a-new-location/](http://www.mikefal.net/2017/01/25/using-powershell-to-restore-to-a-new-location/)
* [http://sqlblog.com/blogs/allen_white/archive/2009/02/19/finding-your-default-file-locations-in-smo.aspx](http://sqlblog.com/blogs/allen_white/archive/2009/02/19/finding-your-default-file-locations-in-smo.aspx)