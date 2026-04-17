# --- Spring Hill Folders Deployment (Team: 1068033) ---
$LogPath = "$env:TEMP\fah-install-log.txt"
Start-Transcript -Path $LogPath -Force

$TeamID = "1068033"
$UserName = "Anonymous"
$InstallerUrl = "https://download.foldingathome.org/releases/public/fah-client/windows-10-64bit/release/fah-client_8.5.5_AMD64.exe"
$InstallerPath = "$env:TEMP\fah-client-v8.exe"
$ConfigDir = "$env:AppData\FAH-Client"
$ConfigPath = "$ConfigDir\config.xml"

Write-Host "--- Spring Hill Folders: Starting Windows Deployment ---" -ForegroundColor Cyan

# 1. Download
Write-Host "[1/4] Downloading official v8.5.5 installer..."
try {
    Invoke-WebRequest -Uri $InstallerUrl -OutFile $InstallerPath -ErrorAction Stop
    Write-Host "  -> Download successful!" -ForegroundColor Green
} catch {
    Write-Host "`n[X] ERROR: Could not download the F@H installer. ($($_.Exception.Message))" -ForegroundColor Red
    Stop-Transcript
    return
}

# 2. Silent Install
Write-Host "[2/4] Installing silently..."
try {
    Start-Process -FilePath $InstallerPath -ArgumentList "/S" -Wait
} catch {
    Write-Host "`n[X] ERROR: Failed to execute the installer. ($($_.Exception.Message))" -ForegroundColor Red
    Stop-Transcript
    return
}

# 3. Configure v8 (Idle-Only + Team)
Write-Host "[3/4] Applying Team $TeamID and Idle-Only mode..."
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

# 4. Startup & Launch
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

Write-Host "[4/4] Launching! Thank you for supporting the team." -ForegroundColor Green
Start-Process -FilePath $ExePath

Stop-Transcript
