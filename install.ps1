# --- Spring Hill Folders Deployment (Team: 1068033) ---
$TeamID = "1068033"
$UserName = "Anonymous"
$InstallerUrl = "https://download.foldingathome.org/releases/public/release/fah-client/windows-10-11-64bit/v8.5/fah-client_8.5.5_AMD64.exe"
$InstallerPath = "$env:TEMP\fah-client-v8.exe"
$ConfigDir = "$env:AppData\FAH-Client"
$ConfigPath = "$ConfigDir\config.xml"

Write-Host "--- Spring Hill Folders: Starting Windows Deployment ---" -ForegroundColor Cyan

# 1. Download
Write-Host "[1/4] Downloading official v8.5.5 installer..."
Invoke-WebRequest -Uri $InstallerUrl -OutFile $InstallerPath

# 2. Silent Install (/S is the standard silent flag)
Write-Host "[2/4] Installing silently..."
Start-Process -FilePath $InstallerPath -ArgumentList "/S" -Wait

# 3. Configure v8 (Idle-Only + Team)
Write-Host "[3/4] Applying Team $TeamID and Idle-Only mode..."
if (!(Test-Path $ConfigDir)) { New-Item -ItemType Directory -Path $ConfigDir }

# Stopping client if already running to write config
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
# Registry key ensures it starts for the user upon login
$StartupPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$ExePath = "$env:ProgramFiles\Folding@home Client\fah-client.exe"
Set-ItemProperty -Path $StartupPath -Name "FoldingAtHome" -Value "`"$ExePath`""

Write-Host "[4/4] Launching! Thank you for supporting the team." -ForegroundColor Green
Start-Process -FilePath $ExePath
