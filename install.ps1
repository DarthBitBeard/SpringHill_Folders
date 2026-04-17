# --- Spring Hill Folders Deployment (Team: 1068033) ---
$LogPath = "$env:TEMP\FAHClient-install-log.txt"
Start-Transcript -Path $LogPath -Force

$TeamID = "1068033"
$UserName = "Anonymous"
$InstallerPath = "$env:TEMP\FAHClient-Installer.exe"

# The exact v8.5+ installation paths
$InstallDir = "$env:ProgramFiles\FAHClient"
$ExePath = "$InstallDir\FAHClient.exe"
$HideConsolePath = "$InstallDir\HideConsole.exe"

Write-Host "--- Spring Hill Folders: Starting Windows Deployment ---" -ForegroundColor Cyan

# 1. Scrape the Raw Directory Server
Write-Host "[1/5] Hunting for the latest official F@H link..."
try {
    $BaseUrl = "https://download.foldingathome.org/releases/public/fah-client/windows-10-64bit/release/"
    $Page = Invoke-WebRequest -Uri $BaseUrl -UseBasicParsing -ErrorAction Stop
    
    $Regex = 'href="(fah-client_([0-9\.]+)_AMD64\.exe)"'
    $Matches = [regex]::Matches($Page.Content, $Regex)
    
    if ($Matches.Count -gt 0) {
        $LatestMatch = $Matches | Sort-Object { [version]$_.Groups[2].Value } | Select-Object -Last 1
        $FileName = $LatestMatch.Groups[1].Value
        $InstallerUrl = $BaseUrl + $FileName
        Write-Host "  -> Found live link: $InstallerUrl" -ForegroundColor Green
    } else {
        throw "Could not find any .exe files in the F@H public directory."
    }
} catch {
    Write-Host "`n[X] ERROR: Directory scraping failed. ($($_.Exception.Message))" -ForegroundColor Red
    Stop-Transcript
    return
}

# 2. Download
Write-Host "[2/5] Downloading official installer..."
try {
    Invoke-WebRequest -Uri $InstallerUrl -OutFile $InstallerPath -ErrorAction Stop
    Write-Host "  -> Download successful!" -ForegroundColor Green
} catch {
    Write-Host "`n[X] ERROR: Could not download the F@H installer. ($($_.Exception.Message))" -ForegroundColor Red
    Stop-Transcript
    return
}

# 3. Silent Install
Write-Host "[3/5] Installing silently..."
try {
    Start-Process -FilePath $InstallerPath -ArgumentList "/S"
    
    # Wait for the installer to actually finish and launch the default app
    $Timer = 0
    while (!(Get-Process -Name "FAHClient" -ErrorAction SilentlyContinue) -and $Timer -lt 30) {
        Start-Sleep -Seconds 2
        $Timer++
    }
} catch {
    Write-Host "`n[X] ERROR: Failed to execute the installer. ($($_.Exception.Message))" -ForegroundColor Red
    Stop-Transcript
    return
}

# 4. Intercept and Kill Factory Defaults
Write-Host "[4/5] Intercepting factory setup..."
Write-Host "  -> Default process detected. Letting it settle..." -ForegroundColor Gray
Start-Sleep -Seconds 8 

Get-Process -Name "FAHClient", "HideConsole" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 3

# 5. Apply Spring Hill Configs (Profile Hunter)
Write-Host "[5/5] Applying Team $TeamID and securing background launch..."

$ConfigContent = @"
<config>
  <user v='$UserName'/>
  <team v='$TeamID'/>
  <idle v='true'/>
</config>
"@

# Write to ProgramData (Global fallback)
$ProgramDataDir = "$env:ProgramData\FAHClient"
if (!(Test-Path $ProgramDataDir)) { New-Item -ItemType Directory -Path $ProgramDataDir -Force | Out-Null }
Set-Content -Path "$ProgramDataDir\config.xml" -Value $ConfigContent -Force

# BEAT THE ADMIN TRAP: Loop through actual human user profiles on the C:\ drive
$UserProfiles = Get-ChildItem -Path "C:\Users" -Directory | Where-Object { $_.Name -notmatch "(Public|Default|Administrator)" }
foreach ($Profile in $UserProfiles) {
    $TargetDir = "$($Profile.FullName)\AppData\Roaming\FAHClient"
    if (!(Test-Path $TargetDir)) { New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null }
    Set-Content -Path "$TargetDir\config.xml" -Value $ConfigContent -Force
}

# Set Startup Routine Globally (HKLM instead of HKCU)
$StartupPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
if (Test-Path $HideConsolePath) {
    $StartupCommand = "`"$HideConsolePath`" `"$ExePath`""
    Set-ItemProperty -Path $StartupPath -Name "FoldingAtHome" -Value $StartupCommand -ErrorAction SilentlyContinue
    
    Start-Process -FilePath $HideConsolePath -ArgumentList "`"$ExePath`""
} else {
    Set-ItemProperty -Path $StartupPath -Name "FoldingAtHome" -Value "`"$ExePath`"" -ErrorAction SilentlyContinue
    Start-Process -FilePath $ExePath -WindowStyle Hidden
}

Write-Host "Launch successful! Thank you for supporting the Spring Hill team." -ForegroundColor Cyan

Start-Sleep -Seconds 5
Start-Process "http://localhost:7396"

Stop-Transcript
