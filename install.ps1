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

# F@H v8 Global Config Directory
$ConfigDir = "$env:ProgramData\FAHClient"
$ConfigPath = "$ConfigDir\config.xml"

Write-Host "--- Spring Hill Folders: Starting Windows Deployment ---" -ForegroundColor Cyan

# 1. Pre-Configure F@H (Write config BEFORE installing)
Write-Host "[1/4] Applying Team $TeamID, GPU access, and Idle-Only mode..."
Get-Process -Name "FAHClient", "HideConsole" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2

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

# 2. Scrape the Raw Directory Server
Write-Host "[2/4] Hunting for the latest official F@H link..."
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

# 3. Download
Write-Host "[3/4] Downloading official installer..."
try {
    Invoke-WebRequest -Uri $InstallerUrl -OutFile $InstallerPath -ErrorAction Stop
    Write-Host "  -> Download successful!" -ForegroundColor Green
} catch {
    Write-Host "`n[X] ERROR: Could not download the F@H installer. ($($_.Exception.Message))" -ForegroundColor Red
    Stop-Transcript
    return
}

# 4. Silent Install
Write-Host "[4/4] Installing silently..."
try {
    # The installer natively sets up the correct startup routine and HideConsole wrappers
    Start-Process -FilePath $InstallerPath -ArgumentList "/S" -Wait
    Write-Host "  -> Waiting for the installer to finish registering..." -ForegroundColor Gray
    Start-Sleep -Seconds 8
} catch {
    Write-Host "`n[X] ERROR: Failed to execute the installer. ($($_.Exception.Message))" -ForegroundColor Red
    Stop-Transcript
    return
}

# Verify it actually installed where we expect it to
if (-not (Test-Path $ExePath)) {
    Write-Host "`n[X] ERROR: Installation finished, but $ExePath is missing." -ForegroundColor Red
    Stop-Transcript
    return
}

# Ensure the process is running hidden using F@H's native wrapper if it didn't auto-start
$FahRunning = Get-Process -Name "FAHClient" -ErrorAction SilentlyContinue
if (-not $FahRunning) {
    if (Test-Path $HideConsolePath) {
        Start-Process -FilePath $HideConsolePath -ArgumentList "`"$ExePath`""
    } else {
        Start-Process -FilePath $ExePath -WindowStyle Hidden
    }
}

Write-Host "Launch successful! Thank you for supporting the Spring Hill team." -ForegroundColor Cyan

# Give the F@H local web server a few seconds to spin up on port 7396 before opening the browser
Start-Sleep -Seconds 5
Start-Process "http://localhost:7396"

Stop-Transcript
