# --- Spring Hill Folders Deployment (Team: 1068033) ---
$LogPath = "$env:TEMP\fah-install-log.txt"
Start-Transcript -Path $LogPath -Force

$TeamID = "1068033"
$UserName = "Anonymous"
$InstallerPath = "$env:TEMP\fah-client-v8.exe"
$ConfigDir = "$env:AppData\FAH-Client"
$ConfigPath = "$ConfigDir\config.xml"

Write-Host "--- Spring Hill Folders: Starting Windows Deployment ---" -ForegroundColor Cyan

# 1. Scrape the Raw Directory Server
Write-Host "[1/4] Hunting for the latest official F@H link..."
try {
    # Hitting the raw file server instead of the front-end website
    $BaseUrl = "https://download.foldingathome.org/releases/public/fah-client/windows-10-64bit/release/"
    $Page = Invoke-WebRequest -Uri $BaseUrl -UseBasicParsing -ErrorAction Stop
    
    # Find all installer files in the directory listing
    $Regex = 'href="(fah-client_([0-9\.]+)_AMD64\.exe)"'
    $Matches = [regex]::Matches($Page.Content, $Regex)
    
    if ($Matches.Count -gt 0) {
        # Sort them by version number to ensure we get the absolute newest one
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

# 3. Silent Install
Write-Host "[3/4] Installing silently..."
try {
    Start-Process -FilePath $InstallerPath -ArgumentList "/S" -Wait
} catch {
    Write-Host "`n[X] ERROR: Failed to execute the installer. ($($_.Exception.Message))" -ForegroundColor Red
    Stop-Transcript
    return
}

# 4. Configure v8 (Idle-Only + Team) & Launch
Write-Host "[4/4] Applying Team $TeamID and Idle-Only mode..."
if (!(Test-Path $ConfigDir)) { New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null }

Stop-Process -Name "fah-client" -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

$ConfigContent = @"
<config>
  <user v='$UserName'/>
  <team v='$TeamID'/>
  <power v='full'/>
  <idle v='true'/>
</config>
"@
Set-Content -Path $ConfigPath -Value $ConfigContent

$ExePaths = @(
    "$env:ProgramFiles\FAH-Client\fah-client.exe",
    "$env:ProgramFiles\Folding@home Client\fah-client.exe",
    "${env:ProgramFiles(x86)}\FAH-Client\fah-client.exe",
    "${env:ProgramFiles(x86)}\Folding@home Client\fah-client.exe"
)

$ExePath = $null
foreach ($Path in $ExePaths) {
    if (Test-Path $Path) {
        $ExePath = $Path
        break
    }
}

if (-not $ExePath) {
    Write-Host "`n[X] ERROR: Could not locate fah-client.exe after installation." -ForegroundColor Red
    Stop-Transcript
    return
}

$StartupPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
Set-ItemProperty -Path $StartupPath -Name "FoldingAtHome" -Value "`"$ExePath`""

Write-Host "Launch successful! Thank you for supporting the Spring Hill team." -ForegroundColor Cyan
Start-Process -FilePath $ExePath

Stop-Transcript
