#Requires -Version 5.1
<#
.SYNOPSIS
    Installs the Folding@home client on Windows, if needed, and sets the
    SpringHill Folders team number without overwriting an existing identity.

.DESCRIPTION
    Review this file before running it. Run it from a downloaded local copy,
    as Administrator, in PowerShell. Do not run it by piping remote content
    into PowerShell. Run with -WhatIf first to see what would change
    without changing anything.

    What this script does, in order:
      1. Checks for Administrator rights.
      2. If the client is not already installed, installs it. By default it
         does not download anything. Pass -InstallerPath with a local
         installer you downloaded from the official site, or pass
         -DownloadLatest to download the official latest.exe alias.
      3. Waits briefly after a fresh install for the client to create its
         own config, then backs up an existing config.xml only if a change
         is needed, and sets only the team number. It adds a username and
         idle setting only when the config does not already have them. It
         never writes, changes, or prints a passkey or account token, and
         it never overwrites an existing username.
      4. Restarts the fah-client service if one exists and the config changed.
         It never force stops a client process and never adds a startup
         registry entry. The official installer already handles startup.

    The recommended path for most people is still the official installer
    plus Web Control at https://app.foldingathome.org . Use this script only
    when you want the team setting applied automatically on a fresh machine
    or across several machines you manage.

    After running it, set a passkey in Web Control if you want Quick Return
    Bonus points. A passkey is different from an account passphrase. See
    https://foldingathome.org/faq/stats

.PARAMETER TeamId
    Folding@home team number. Default: 1068033 (SpringHill Folders).

.PARAMETER UserName
    Username used only when no username is already configured. Default:
    anonymous. Letters, numbers, and underscores only. Usernames are
    case sensitive in Folding@home stats.

.PARAMETER Idle
    Set folding to run only when idle, when a config value is written.

.PARAMETER NoIdle
    Do not set folding to idle only. Cannot be used with -Idle.

.PARAMETER InstallerPath
    Path to a local Folding@home Windows installer (.exe) you already
    downloaded from https://foldingathome.org/download

.PARAMETER DownloadLatest
    Download the official latest.exe alias from download.foldingathome.org
    and install it. Only used when the client is not already installed.

.PARAMETER OpenWebControl
    Open https://app.foldingathome.org in the default browser when done.

.PARAMETER Force
    Skip the confirmation prompt for downloading or installing.

.EXAMPLE
    # Configure team on a machine where the client is already installed:
    .\install.ps1

.EXAMPLE
    # Install from a local installer, then configure team:
    .\install.ps1 -InstallerPath "$env:USERPROFILE\Downloads\fah-client_8.5.6_AMD64.exe"

.EXAMPLE
    # Download the official latest installer, then install and configure:
    .\install.ps1 -DownloadLatest

.NOTES
    Tested against the v8.5 client model described at
    https://foldingathome.org/guides/v8-5 . The download alias below was
    checked on 2026-10-27 and pointed at 8.5.6. The alias, not a pinned
    version, is used so the script does not go stale on a patch release.
    If the alias stops working, download the installer from the official
    download page and use -InstallerPath.
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [ValidatePattern('^\d+$')]
    [string]$TeamId = '1068033',

    [ValidatePattern('^[A-Za-z0-9_]+$')]
    [string]$UserName = 'anonymous',

    [switch]$Idle,

    [switch]$NoIdle,

    [string]$InstallerPath,

    [switch]$DownloadLatest,

    [switch]$OpenWebControl,

    [switch]$Force
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$WebControlUrl = 'https://app.foldingathome.org'
$DownloadUrl = 'https://download.foldingathome.org/releases/public/fah-client/windows-10-64bit/release/latest.exe'
$InstallDir = Join-Path $env:ProgramFiles 'FAHClient'
$ExePath = Join-Path $InstallDir 'FAHClient.exe'

if ($Idle -and $NoIdle) {
    throw 'Use only one of -Idle or -NoIdle.'
}

# Administrator rights are needed to install and to write ProgramData config.
$principal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent()
)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run this script as Administrator. Right click PowerShell, choose Run as administrator, then run the downloaded script file.'
}

function Backup-File {
    param([Parameter(Mandatory = $true)][string]$Path)
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backup = "$Path.bak.$stamp"
    Copy-Item -Path $Path -Destination $backup -Force | Out-Null
    return $backup
}

function Get-ExistingConfigPaths {
    $candidates = @(
        (Join-Path $env:ProgramData 'FAHClient\config.xml'),
        (Join-Path $env:APPDATA 'FAHClient\config.xml')
    )
    $found = @()
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            $found += $candidate
        }
    }
    return $found
}

function Get-ExistingConfigPath {
    $found = @(Get-ExistingConfigPaths)
    if ($found.Count -gt 1) {
        Write-Host "Warning: config files were found in more than one location. Only the first will be edited. Check the other one in Web Control: $($found -join ', ')"
    }
    if ($found.Count -gt 0) {
        return $found[0]
    }
    return $null
}

function Wait-ForConfig {
    param([int]$Seconds = 30)
    $deadline = (Get-Date).AddSeconds($Seconds)
    while ((Get-Date) -lt $deadline) {
        $found = Get-ExistingConfigPath
        if ($null -ne $found) {
            return $found
        }
        Start-Sleep -Seconds 2
    }
    return $null
}

function Set-ConfigValue {
    param(
        [Parameter(Mandatory = $true)][System.Xml.XmlDocument]$Xml,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Value,
        [bool]$OnlyIfMissing = $false
    )
    $node = $Xml.config.SelectSingleNode($Name)
    if ($null -eq $node) {
        $node = $Xml.CreateElement($Name)
        [void]$Xml.config.AppendChild($node)
        $node.SetAttribute('v', $Value)
        return 'added'
    }
    if ($OnlyIfMissing) {
        return 'kept'
    }
    if ($node.GetAttribute('v') -eq $Value) {
        return 'kept'
    }
    $node.SetAttribute('v', $Value)
    return 'updated'
}

Write-Host 'SpringHill Folders: Folding@home Windows setup (Team 1068033)' -ForegroundColor Cyan
Write-Host "Web Control: $WebControlUrl"

# 1. Install the client only if it is missing.
$installed = Test-Path -LiteralPath $ExePath
$justInstalled = $false
if (-not $installed) {
    $installer = $null

    if ($InstallerPath) {
        $installer = (Resolve-Path -LiteralPath $InstallerPath).Path
        if (-not $installer.EndsWith('.exe', [StringComparison]::OrdinalIgnoreCase)) {
            throw "InstallerPath must point to a .exe installer: $InstallerPath"
        }
        Write-Host "Using local installer: $installer"
    }
    elseif ($DownloadLatest) {
        $installer = Join-Path $env:TEMP 'fah-client-latest.exe'
        $action = "Download official Folding@home installer from $DownloadUrl"
        if ($Force -or $PSCmdlet.ShouldProcess($installer, $action)) {
            Write-Host 'Downloading the official latest installer...'
            try {
                [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
            }
            catch {
                Write-Host 'Could not set TLS 1.2 explicitly. Continuing with the system default.'
            }
            Invoke-WebRequest -Uri $DownloadUrl -OutFile $installer -UseBasicParsing
            $size = (Get-Item -LiteralPath $installer).Length
            if ($size -lt 1000000) {
                throw "Downloaded installer looks too small ($size bytes). Delete it and download from https://foldingathome.org/download instead."
            }
            Write-Host "Downloaded installer ($size bytes)."
            try {
                $signature = Get-AuthenticodeSignature -LiteralPath $installer
                Write-Host "Installer signature status: $($signature.Status). This is informational only. If the status is not Valid, stop and download from https://foldingathome.org/download instead."
            }
            catch {
                Write-Host 'Could not check the installer signature. Continuing. Download from https://foldingathome.org/download if you want to verify it yourself.'
            }
        }
    }
    else {
        throw @'
Folding@home does not appear to be installed, and no installer was given.
Download the installer from https://foldingathome.org/download , then rerun with:
  .\install.ps1 -InstallerPath "<path to the downloaded .exe>"
Or rerun with -DownloadLatest to download the official latest.exe alias.
'@
    }

    if ($installer) {
        $action = "Install Folding@home silently from $installer"
        if ($Force -or $PSCmdlet.ShouldProcess($ExePath, $action)) {
            Write-Host 'Installing silently. This can take a minute...'
            $process = Start-Process -FilePath $installer -ArgumentList '/S' -Wait -PassThru
            if ($process.ExitCode -ne 0) {
                throw "Installer exited with code $($process.ExitCode). Check the installer and try the manual install from https://foldingathome.org/download"
            }
            if (-not (Test-Path -LiteralPath $ExePath)) {
                throw "Install finished, but the client was not found at $ExePath. Install manually from https://foldingathome.org/download"
            }
            $justInstalled = $true
            Write-Host 'Install finished.'
            if ($DownloadLatest) {
                Remove-Item -LiteralPath $installer -ErrorAction SilentlyContinue
            }
        }
    }
}
else {
    Write-Host 'Folding@home client already installed. Skipping download and install.'
}

# 2. Update config, preserving any existing identity.
# If the client was just installed, give it a short time to create its own
# config on first run before this script creates one. That avoids writing
# a config the client then overwrites.
$existingPath = Get-ExistingConfigPath
if (($null -eq $existingPath) -and $justInstalled) {
    Write-Host 'Waiting briefly for the newly installed client to create its config...'
    $existingPath = Wait-ForConfig -Seconds 30
}

$configChanged = $false
$backupPath = $null
$configOutcome = 'not set by this script. Set the team in Web Control.'

if ($null -ne $existingPath) {
    try {
        [xml]$xml = Get-Content -LiteralPath $existingPath -Raw
    }
    catch {
        throw "Existing config at $existingPath is not valid XML. No backup was made because nothing was changed. Set the team in Web Control instead of letting this script rewrite the file. Error: $($_.Exception.Message)"
    }
    if ($null -eq $xml.config) {
        throw "Existing config at $existingPath has no <config> root. No change was made. Set the team in Web Control instead."
    }

    $hasSecret = $false
    foreach ($secretName in @('passkey', 'account-token')) {
        if ($null -ne $xml.config.SelectSingleNode($secretName)) {
            $hasSecret = $true
        }
    }
    if ($hasSecret) {
        Write-Host 'A passkey or account token is already configured. It will be preserved and will not be printed.'
    }

    # Compute the changes in memory first, so a backup is only made when
    # something actually needs to change.
    $teamResult = Set-ConfigValue -Xml $xml -Name 'team' -Value $TeamId
    $userResult = Set-ConfigValue -Xml $xml -Name 'user' -Value $UserName -OnlyIfMissing $true

    $idleResult = 'kept'
    if ($Idle) {
        $idleResult = Set-ConfigValue -Xml $xml -Name 'idle' -Value 'true'
    }
    elseif ($NoIdle) {
        $idleResult = Set-ConfigValue -Xml $xml -Name 'idle' -Value 'false'
    }

    $needsSave = ($teamResult -eq 'updated') -or ($userResult -eq 'added') -or ($idleResult -in @('added', 'updated'))
    if (-not $needsSave) {
        $configOutcome = "already set for team $TeamId in $existingPath. No change was made."
        Write-Host "Config already set for this team. No change made to: $existingPath"
    }
    elseif ($Force -or $PSCmdlet.ShouldProcess($existingPath, "Update team to $TeamId")) {
        $backupPath = Backup-File -Path $existingPath
        Write-Host "Backed up existing config to: $backupPath"
        $configChanged = $true
        $tempPath = "$existingPath.tmp"
        $xml.Save($tempPath)
        Move-Item -LiteralPath $tempPath -Destination $existingPath -Force
        $configOutcome = "set to team $TeamId in $existingPath (team: $teamResult, user: $userResult, idle: $idleResult)."
        Write-Host "Config updated: $existingPath (team: $teamResult, user: $userResult, idle: $idleResult)"
    }
    else {
        $configOutcome = "would be set to team $TeamId in $existingPath, but -WhatIf was used, so nothing was changed."
        Write-Host "WhatIf: config would be updated (team: $teamResult, user: $userResult, idle: $idleResult), but nothing was changed."
    }
}
else {
    # No config yet. Create a minimal one in the ProgramData location only.
    # Do not write a copy into every user profile.
    $configDir = Join-Path $env:ProgramData 'FAHClient'
    $configPath = Join-Path $configDir 'config.xml'
    $idleValue = 'true'
    if ($NoIdle) {
        $idleValue = 'false'
    }
    if ($Force -or $PSCmdlet.ShouldProcess($configPath, "Create minimal config for team $TeamId")) {
        if (-not (Test-Path -LiteralPath $configDir)) {
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        }
        [xml]$xml = New-Object System.Xml.XmlDocument
        $declaration = $xml.CreateXmlDeclaration('1.0', 'UTF-8', $null)
        [void]$xml.AppendChild($declaration)
        $root = $xml.CreateElement('config')
        [void]$xml.AppendChild($root)
        foreach ($pair in @( @{ Name = 'user'; Value = $UserName }, @{ Name = 'team'; Value = $TeamId }, @{ Name = 'idle'; Value = $idleValue } )) {
            $node = $xml.CreateElement($pair.Name)
            $node.SetAttribute('v', $pair.Value)
            [void]$root.AppendChild($node)
        }
        $xml.Save($configPath)
        $configChanged = $true
        $configOutcome = "set to team $TeamId in new config $configPath (user: $UserName, idle: $idleValue)."
        Write-Host "Created minimal config: $configPath (user: $UserName, team: $TeamId, idle: $idleValue)"
        Write-Host 'Set a passkey and any other preferences in Web Control. This script never writes a passkey.'
    }
    else {
        $configOutcome = "would be set to team $TeamId in a new config at $configPath, but -WhatIf was used, so nothing was created."
        Write-Host "WhatIf: a minimal config would be created at $configPath, but nothing was created."
    }
}

# 3. Restart the service gracefully if one exists and the config changed.
if ($configChanged) {
    $service = Get-Service -Name 'fah-client' -ErrorAction SilentlyContinue
    if ($null -ne $service) {
        if ($Force -or $PSCmdlet.ShouldProcess('fah-client', 'Restart service')) {
            Restart-Service -Name 'fah-client' -ErrorAction Stop
            Write-Host 'Restarted the fah-client service.'
        }
    }
    else {
        Write-Host 'No fah-client service was found. If the client is already running, restart it from Web Control or restart the computer so the new team setting takes effect.'
    }
}

Write-Host ''
Write-Host "Done. Team $configOutcome"
Write-Host "Open Web Control to check folding and add a passkey: $WebControlUrl"
Write-Host 'Passkey help: https://foldingathome.org/faq/stats'
if ($OpenWebControl) {
    if ($Force -or $PSCmdlet.ShouldProcess($WebControlUrl, 'Open Web Control')) {
        Start-Process $WebControlUrl
    }
}
