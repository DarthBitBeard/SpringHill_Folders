# --- Spring Hill Folders Deployment (Team: 1068033) ---
$TeamID = "1068033"
$UserName = "Anonymous"

# Fallback array to combat F@H changing their directory structures
$Urls = @(
    "https://download.foldingathome.org/releases/public/release/fah-client/windows-10-64bit/v8.3/latest.exe",
    "https://download.foldingathome.org/releases/public/release/fah-client/windows-10-64bit/latest.exe",
    "https://download.foldingathome.org/releases/public/release/fah-client-next/windows-10-64bit/release/latest.exe"
)

$InstallerPath = "$env:TEMP\fah-client-v8.exe"
$ConfigDir = "$env:AppData\FAH-Client"
$ConfigPath = "$ConfigDir\config.xml"

Write-Host "--- Spring Hill Folders: Starting Windows Deployment ---" -ForegroundColor Cyan

# 1. Download with Fallbacks
Write-Host "[1/4] Downloading official v8 installer..."
$Downloaded = $false

foreach ($Url in $Urls) {
    try {
        Write-Host "  -> Attempting: $Url" -ForegroundColor Gray
        Invoke-WebRequest -Uri $Url -OutFile $InstallerPath -ErrorAction Stop
        $Downloaded = $true
        Write-Host "  -> Download successful!" -ForegroundColor Green
        break
    } catch {
        Write-Host "  -> 404/Error. Trying next URL..." -ForegroundColor DarkYellow
    }
}

if (-not $Downloaded -or -not (Test-Path $InstallerPath)) {
    Write-Host "`n[X] ERROR: Could not download the F@H installer. All URLs failed." -ForegroundColor Red
    Write-Host "Please verify the official download link at foldingathome.org" -ForegroundColor Red
    Read-Host "Press Enter to exit..."
    return
}

# 2. Silent Install
Write-Host "[2/4] Installing silently..."
try {
    Start-Process -FilePath $InstallerPath -ArgumentList "/S" -Wait
} catch {
    Write-Host "`n[X] ERROR: Failed to execute the installer." -ForegroundColor Red
    Read-Host "Press Enter to exit..."
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
    Read-Host "Press Enter to exit..."
    return
}

$StartupPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
Set-ItemProperty -Path $StartupPath -Name "FoldingAtHome" -Value "`"$ExePath`""

Write-Host "[4/4] Launching! Thank you for supporting the team." -ForegroundColor Green
Start-Process -FilePath $ExePath
