# --- Spring Hill Folders Deployment (Team: 1068033) ---
$LogPath = "$env:TEMP\FAHClient-install-log.txt"
Start-Transcript -Path $LogPath -Force

$TeamID = "1068033"
$UserName = "Anonymous"
$InstallerPath = "$env:TEMP\FAHClient-Installer.exe"

# The exact v8.5+ installation paths
$InstallDir = "$env:ProgramFiles\FAHClient"
$ExePath = "$InstallDir\FAHClient.exe"
$ConfigDir = "$env:ProgramData\FAHClient"
$ConfigPath = "$ConfigDir\config.xml"

Write-Host "--- Spring Hill Folders: Starting Windows Deployment ---" -ForegroundColor Cyan

# 1. Scrape the Raw Directory Server
Write-Host "[1/4] Hunting for the latest official F@H link..."
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
Write-Host "[2/4] Downloading official installer..."
try {
    Invoke-WebRequest -Uri $InstallerUrl -OutFile $InstallerPath -ErrorAction Stop
    Write-Host "  -> Download successful!" -ForegroundColor Green
} catch {
    Write-Host "`n[X] ERROR: Could not download the F@H installer. ($($_.Exception.Message))" -ForegroundColor Red
    Stop-Transcript
    return
}

# 3. Silent Install (with Asynchronous Guard Dog)
Write-Host "[3/4] Installing silently..."
try {
    Start-Process -FilePath $InstallerPath -ArgumentList "/S"
    Write-Host "  -> Waiting for the background installer to unpack and finish..." -ForegroundColor Gray
    
    # Loop to wait until the FAHClient.exe actually appears on the hard drive (up to 60 seconds)
    $Timer = 0
    while (!(Test-Path $ExePath) -and $Timer -lt 30) {
        Start-Sleep -Seconds 2
        $Timer++
    }
    
    # Give the installer 10 extra seconds to write its default configs and start the service
    Write-Host "  -> Files found! Waiting for background service registration..." -ForegroundColor Gray
    Start-Sleep -Seconds 10
} catch {
    Write-Host "`n[X] ERROR: Failed to execute the installer. ($($_.Exception.Message))" -ForegroundColor Red
    Stop-Transcript
    return
}

if (-not (Test-Path $ExePath)) {
    Write-Host "`n[X] ERROR: Installation timed out. $ExePath is missing." -ForegroundColor Red
    Stop-Transcript
    return
}

# 4. Configure v8 (Idle-Only, GPUs Enabled + Team)
Write-Host "[4/4] Applying Team $TeamID, GPU access, and Idle-Only mode..."

# Brutally kill the background process so we have total control over the config file
Get-Process -Name "FAHClient" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 3

if (-not (Test-Path $ConfigDir)) { New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null }

$ConfigContent = @"
<config>
  <user v='$UserName'/>
  <team v='$TeamID'/>
  <power v='full'/>
  <idle v='true'/>
  <gpu v='true'/>
</config>
"@
Set-Content -Path $ConfigPath -Value $ConfigContent

# Set to start automatically on Windows boot
$StartupPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
Set-ItemProperty -Path $StartupPath -Name "FoldingAtHome" -Value "`"$ExePath`""

# Start the application process back up!
Start-Process -FilePath $ExePath

Write-Host "Launch successful! Thank you for supporting the Spring Hill team." -ForegroundColor Cyan

# Give the F@H local web server a few seconds to spin up on port 7396 before opening the browser
Start-Sleep -Seconds 4
Start-Process "http://localhost:7396"

Stop-Transcript
