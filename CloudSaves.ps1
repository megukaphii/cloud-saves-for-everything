class CloudSaves {
    [string]$CloudSavesDir = ""
    [string]$BackupDir = ""
    [string]$TempDir = ""

    [int32]$SuccessCount = 0
    [boolean]$WarningsOccured = $false

    [string[]]$Config
    [string[]]$DirectoryMap

    CloudSaves ([string[]]$config, [string[]]$directoryMap) {
        $this.Config = $config
        $this.DirectoryMap = $directoryMap
    }

    [void] AddDivider () {
        $consoleInfo = MODE CON | Select-Object -Skip 4 | ForEach-Object { $_.Trim() }
        $columns = $consoleInfo[0] -replace '\D+(\d+)', '$1'
        $divider = "*" * $columns
        Write-Host $divider
        Write-Host ""
    }

    [void] LogError ([string]$GameName, [string]$ProcessDescription, [string[]]$ErrorOutput) {
        $ErrorOutput >> Errors.log
        $GameName >> FailedGames.log
        $this.AddDivider()
        Write-Host "Error occurred during $ProcessDescription for $GameName." -ForegroundColor Red
        Write-Host "Process failed with errors." -ForegroundColor Red
        Pause
        exit
    }

    [void] ClearLogs () {
        Clear-Content -Path CompletedGames.log -ErrorAction SilentlyContinue
        Clear-Content -Path SkippedGames.log -ErrorAction SilentlyContinue
        Clear-Content -Path OverwrittenGames.log -ErrorAction SilentlyContinue
        Clear-Content -Path FailedGames.log -ErrorAction SilentlyContinue
        Clear-Content -Path Errors.log -ErrorAction SilentlyContinue
    }

    [void] GetConfig () {
        foreach ($line in $this.Config) {
            if ($line -match '^\s*([^=]+)\s*=\s*(.+)\s*$') {
                $key = $matches[1].Trim()
                $value = $matches[2].Trim()
        
                switch ($key) {
                    "cloudSavesDir" {
                        $this.CloudSavesDir = $value -replace "%USERPROFILE%", $env:USERPROFILE
                        $str = "Cloud save directory set to " + $this.CloudSavesDir + "\"
                        Write-Host $str
                        break
                    }
                    "backupDir" {
                        $this.BackupDir = $value -replace "%USERPROFILE%", $env:USERPROFILE
                        $str = "Backup directory set to " + $this.BackupDir + "\"
                        Write-Host $str
                        break
                    }
                    "tempDir" {
                        $this.TempDir = $value -replace "%USERPROFILE%", $env:USERPROFILE
                        $str = "Temp directory set to " + $this.TempDir + "\"
                        Write-Host $str
                        break
                    }
                }
            }
        }
        Write-Host ""
    }

    [void] DenyVar ([string]$Var) {
        Write-Host $Var "not defined in Config.txt!" -ForegroundColor Red
        Pause
        exit
    }

    [void] ClearBackup ([string]$GameName, [string]$GameBackupDir) {
        if (Test-Path $GameBackupDir -PathType Container) {
            Write-Host "Removing $GameName backup..."
            $errorOutput = ""
            Remove-Item -Path $GameBackupDir -Recurse -Force -ErrorAction SilentlyContinue -ErrorVariable errorOutput
            if ($errorOutput -ne "") {
                $this.LogError($GameName, "backup flush", $errorOutput)
            }
        }
    }

    [void] BackupSaves ([string]$GameName, [string]$LocalDir, [string]$GameBackupDir) {
        Write-Host "Backing up $GameName save folder..."
        $errorOutput = robocopy.exe $LocalDir $GameBackupDir /e
        if ($LASTEXITCODE -ge 8) {
            $this.LogError($GameName, "backup creation", $errorOutput)
        }
    }

    [void] TestOverwrite ([string]$GameName, [string]$LocalDir, [string]$CloudGameDir) {
        robocopy.exe $CloudGameDir $this.TempDir /mir
        robocopy.exe $LocalDir $CloudGameDir /e /xl
        if ($LASTEXITCODE -eq 1) {
            Write-Host "Files for $GameName with the same name exist locally and could be lost. Check your backup directory if you need to restore them." -ForegroundColor Yellow
            $this.WarningsOccured = $true
            $GameName >> OverwrittenGames.log
        }
        robocopy.exe $this.TempDir $CloudGameDir /mir /move
    }

    [void] CopySaves ([string]$GameName, [string]$LocalDir, [string]$CloudGameDir) {
        Write-Host "Copying $GameName save folder to Cloud storage..."

        if (Test-Path $CloudGameDir -PathType Container) {
            $this.TestOverwrite($GameName, $LocalDir, $CloudGameDir)
        }

        $result = robocopy.exe $LocalDir $CloudGameDir /e /xc /xn /xo
        if ($LASTEXITCODE -ge 8) {
            $this.LogError($GameName, "save to Cloud storage", $result)
        }
    }

    [void] RemoveLocal ([string]$GameName, [string]$LocalDir) {
        Write-Host "Removing local $GameName save folder..."
        $errorOutput = ""
        Remove-Item -Path $LocalDir -Recurse -Force -ErrorAction SilentlyContinue -ErrorVariable errorOutput
        if ($errorOutput -ne "") {
            $this.LogError($GameName, "local save folder deletion", $errorOutput)
        }
    }

    [void] NewJunction ([string]$GameName, [string] $LocalDir, [string]$CloudGameDir) {
        Write-Host "Establishing $GameName junction..."
        $errorOutput = ""
        try {
            New-Item -ItemType Junction -Path $LocalDir -Target $CloudGameDir -ErrorAction SilentlyContinue -ErrorVariable errorOutput > $null
            if ($errorOutput -ne "") {
                $this.LogError($GameName, "junction creation", $errorOutput)
            }
        } catch {
            $this.LogError($GameName, "junction creation", $errorOutput)
        }
    }

    [void] RemoveBackups () {
        if (-not $this.WarningsOccured -and $this.SuccessCount -ne 0) {
            Write-Host "Removing backups folder..."
            $errorOutput = ""
            Remove-Item -Path $this.BackupDir -Recurse -Force -ErrorAction SilentlyContinue -ErrorVariable errorOutput
            if ($errorOutput -ne "") {
                $this.LogError("all games", "final backup removal", $errorOutput)
            }
        }
    }

    [void] InitializeResources () {
        $this.ClearLogs()
        $this.GetConfig()
        if ($this.CloudSavesDir -eq "") {
            $this.DenyVar("CloudSavesDir")
        }
        if ($this.BackupDir -eq "") {
            $this.DenyVar("BackupDir")
        }
        if (-not (Test-Path $this.CloudSavesDir -PathType Container)) {
            New-Item -Path $this.CloudSavesDir -ItemType Directory
        }
        $this.AddDivider()
    }

    [boolean] TestReparsePoint ([string]$Path) {
        $file = Get-Item $Path -Force -ea SilentlyContinue
        return [bool]($file.Attributes -band [IO.FileAttributes]::ReparsePoint)
    }

    [void] SkipExistingGame ([string]$GameName) {
        Write-Host "$GameName appears to already be syncing." -ForegroundColor Yellow
        Write-Host ""
        $GameName >> SkippedGames.log
    }

    [void] InvokeGame ([string]$GameName, [string]$LocalDir, [string]$CloudGameDir) {
        $gameBackupDir = Join-Path $this.BackupDir $GameName

        $this.ClearBackup($GameName, $gameBackupDir)
        $this.BackupSaves($GameName, $LocalDir, $gameBackupDir)
        $this.CopySaves($GameName, $LocalDir, $CloudGameDir)
        $this.RemoveLocal($GameName, $LocalDir)
        $this.NewJunction($GameName, $LocalDir, $CloudGameDir)
        if (-not $this.WarningsOccured) {
            $this.ClearBackup($GameName, $gameBackupDir)
        }

        Write-Host "Successfully set up Cloud saves for $GameName!" -ForegroundColor Green
        Write-Host ""
        $this.SuccessCount += 1
        $GameName >> CompletedGames.log
    }

    [void] AddAndInvokeGame ([string]$GameName, [string]$LocalDir, [string]$CloudGameDir) {
        New-Item -Path $LocalDir -ItemType Directory
        Write-Host "Save folder for $GameName created." -ForegroundColor Blue
        $this.InvokeGame($GameName, $LocalDir, $CloudGameDir)
    }

    [void] CompleteProcess () {
        $this.RemoveBackups()
        Remove-Item OverwrittenGames.log -ErrorAction SilentlyContinue
        Remove-Item FailedGames.log -ErrorAction SilentlyContinue
        Remove-Item Errors.log -ErrorAction SilentlyContinue

        $this.AddDivider()
        if ($this.WarningsOccured) {
            Write-Host "Synced" $this.SuccessCount "games. Process completed with warnings." -ForegroundColor Yellow
        } else {
            Write-Host "Synced" $this.SuccessCount "games. Process completed with no errors!" -ForegroundColor Green
        }
        Pause
        exit
    }

    [void] InvokeProcess () {
        $this.InitializeResources()
        foreach ($line in $this.DirectoryMap) {
            $localDir, $gameName = $line -split ","
            $localDir = $localDir.Trim() -replace "%USERPROFILE%", $env:USERPROFILE
            $gameName = $gameName.Trim()
            $cloudGameDir = Join-Path $this.CloudSavesDir $gameName

            if (Test-Path $localDir -PathType Container) {
                if ($this.TestReparsePoint($localDir)) {
                    $this.SkipExistingGame($gameName)
                } else {
                    $this.InvokeGame($gameName, $localDir, $cloudGameDir)
                }
            } else {
                $this.AddAndInvokeGame($gameName, $localDir, $cloudGameDir)
            }
        }
        $this.CompleteProcess()
    }
}

$configFile = "Config.txt"
$config = Get-Content -Path $configFile
$directoryMapFile = "DirectoryMap.txt"
$directoryMap = Get-Content -Path $directoryMapFile

[CloudSaves]$app = [CloudSaves]::new($config, $directoryMap)
$app.InvokeProcess()