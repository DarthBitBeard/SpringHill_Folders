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
Start-Sleep -Seconds 8 # Give it time to release file locks

# Mercilessly kill the app so we have total control over the config files
Get-Process -Name "FAHClient", "HideConsole" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 3

# 5. Apply Spring Hill Configs & Secure Background Launch
Write-Host "[5/5] Applying Team $TeamID and securing background launch..."

$ConfigContent = @"
<config>
  <user v='$UserName'/>
  <team v='$TeamID'/>
  <idle v='true'/>
</config>
"@

# We write to BOTH ProgramData (Machine-wide) and AppData (User-level) to beat the Admin trap
$ProgramDataDir = "$env:ProgramData\FAHClient"
if (!(Test-Path $ProgramDataDir)) { New-Item -ItemType Directory -Path $ProgramDataDir -Force | Out-Null }
Set-Content -Path "$ProgramDataDir\config.xml" -Value $ConfigContent -Force

$AppDataDir = "$env:AppData\FAHClient"
if (!(Test-Path $AppDataDir)) { New-Item -ItemType Directory -Path $AppDataDir -Force | Out-Null }
Set-Content -Path "$AppDataDir\config.xml" -Value $ConfigContent -Force

# Set the Startup Routine to use the HideConsole wrapper!
$StartupPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
if (Test-Path $HideConsolePath) {
    $StartupCommand = "`"$HideConsolePath`" `"$ExePath`""
    Set-ItemProperty -Path $StartupPath -Name "FoldingAtHome" -Value $StartupCommand
    
    # Launch it right now invisibly
    Start-Process -FilePath $HideConsolePath -ArgumentList "`"$ExePath`""
} else {
    # Fallback just in case
    Set-ItemProperty -Path $StartupPath -Name "FoldingAtHome" -Value "`"$ExePath`""
    Start-Process -FilePath $ExePath -WindowStyle Hidden
}

Write-Host "Launch successful! Thank you for supporting the Spring Hill team." -ForegroundColor Cyan

# Give the local web server time to spin up, then open the dashboard
Start-Sleep -Seconds 5
Start-Process "http://localhost:7396"

Stop-Transcript
