#Requires -RunAsAdministrator
<#
.SYNOPSIS
    NeoTiny11 Gaming Builder - ISO Builder
.DESCRIPTION
    Finalizes the Windows image and creates a bootable ISO.
.PARAMETER ScratchPath
    Path to the scratch directory containing the modified image
.PARAMETER OutputPath
    Path where the final ISO will be saved
.PARAMETER Config
    Configuration object with build settings
.PARAMETER ToolsPath
    Path to tools directory (oscdimg.exe)
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ScratchPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [Parameter(Mandatory = $true)]
    [PSCustomObject]$Config,

    [Parameter(Mandatory = $true)]
    [string]$ToolsPath
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message, [string]$Status = "INFO")
    $color = switch ($Status) {
        "INFO"    { "Cyan" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR"   { "Red" }
        default   { "White" }
    }
    $prefix = switch ($Status) {
        "INFO"    { "    [*]" }
        "SUCCESS" { "    [+]" }
        "WARNING" { "    [!]" }
        "ERROR"   { "    [X]" }
        default   { "    [-]" }
    }
    Write-Host "$prefix $Message" -ForegroundColor $color
}

$mountPath = "$ScratchPath\mount"
$isoPath = "$ScratchPath\iso"
$wimPath = "$ScratchPath\install.wim"

# ============================================================================
# UNMOUNT WIM
# ============================================================================
Write-Step "Saving and unmounting Windows image..." "INFO"

# Commit changes and unmount
dism /English /Unmount-Wim /MountDir:"$mountPath" /Commit
if ($LASTEXITCODE -ne 0) {
    Write-Step "Failed to unmount WIM image!" "ERROR"
    dism /English /Unmount-Wim /MountDir:"$mountPath" /Discard
    exit 1
}

Write-Step "Image unmounted and saved" "SUCCESS"

# ============================================================================
# EXPORT TO RECOVERY COMPRESSION (Smaller Size)
# ============================================================================
Write-Step "Compressing image for smaller ISO size..." "INFO"

$finalWim = "$isoPath\sources\install.wim"

# Remove old WIM/ESD from iso folder
if (Test-Path "$isoPath\sources\install.wim") {
    Remove-Item "$isoPath\sources\install.wim" -Force
}
if (Test-Path "$isoPath\sources\install.esd") {
    Remove-Item "$isoPath\sources\install.esd" -Force
}

# Export with recovery compression (best for USB install)
Write-Step "Exporting with maximum compression..." "INFO"
dism /English /Export-Image /SourceImageFile:"$wimPath" /SourceIndex:1 /DestinationImageFile:"$finalWim" /Compress:recovery /CheckIntegrity

if ($LASTEXITCODE -ne 0) {
    Write-Step "Compression failed, trying standard max compression..." "WARNING"
    dism /English /Export-Image /SourceImageFile:"$wimPath" /SourceIndex:1 /DestinationImageFile:"$finalWim" /Compress:max
}

Write-Step "Image compression complete" "SUCCESS"

# ============================================================================
# CREATE AUTOUNATTEND.XML (Bypass Microsoft Account)
# ============================================================================
if ($Config.Installation.AutoUnattend) {
    Write-Step "Creating autounattend.xml for unattended installation..." "INFO"

    $autoUnattendContent = @'
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="windowsPE">
        <component name="Microsoft-Windows-International-Core-WinPE" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <SetupUILanguage>
                <UILanguage>en-US</UILanguage>
            </SetupUILanguage>
            <InputLocale>en-US</InputLocale>
            <SystemLocale>en-US</SystemLocale>
            <UILanguage>en-US</UILanguage>
            <UserLocale>en-US</UserLocale>
        </component>
        <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <UserData>
                <AcceptEula>true</AcceptEula>
            </UserData>
        </component>
    </settings>
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <HideLocalAccountScreen>false</HideLocalAccountScreen>
                <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
                <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
                <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
                <ProtectYourPC>3</ProtectYourPC>
            </OOBE>
            <FirstLogonCommands>
                <SynchronousCommand wcm:action="add">
                    <Order>1</Order>
                    <CommandLine>reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE" /v BypassNRO /t REG_DWORD /d 1 /f</CommandLine>
                    <Description>Bypass Network Requirement</Description>
                </SynchronousCommand>
            </FirstLogonCommands>
        </component>
    </settings>
</unattend>
'@

    $autoUnattendContent | Out-File -FilePath "$isoPath\autounattend.xml" -Encoding UTF8 -Force
    Write-Step "autounattend.xml created" "SUCCESS"

    # Also create bypass script for manual use
    $bypassScript = @'
@echo off
:: Run this if OOBE asks for Microsoft Account
:: It enables the "I don't have internet" option
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE" /v BypassNRO /t REG_DWORD /d 1 /f
shutdown /r /t 0
'@

    $bypassScript | Out-File -FilePath "$isoPath\BypassMSAccount.cmd" -Encoding ASCII -Force
}

# ============================================================================
# FIND OSCDIMG
# ============================================================================
Write-Step "Locating oscdimg.exe..." "INFO"

$oscdimgPath = $null

# Check tools folder first
if (Test-Path "$ToolsPath\oscdimg.exe") {
    $oscdimgPath = "$ToolsPath\oscdimg.exe"
}
# Check Windows ADK paths
elseif (Test-Path "${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe") {
    $oscdimgPath = "${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"
}
elseif (Test-Path "${env:ProgramFiles}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe") {
    $oscdimgPath = "${env:ProgramFiles}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"
}
else {
    # Try to download
    Write-Step "oscdimg.exe not found, attempting download..." "WARNING"

    $downloadPath = "$ToolsPath\oscdimg.exe"
    try {
        $oscdimgUrl = "https://msdl.microsoft.com/download/symbols/oscdimg.exe/3D44737265000/oscdimg.exe"
        Invoke-WebRequest -Uri $oscdimgUrl -OutFile $downloadPath -UseBasicParsing
        $oscdimgPath = $downloadPath
        Write-Step "oscdimg.exe downloaded successfully" "SUCCESS"
    }
    catch {
        Write-Step "Failed to download oscdimg.exe" "ERROR"
        Write-Step "Please install Windows ADK or manually download oscdimg.exe" "ERROR"
        exit 1
    }
}

Write-Step "Using oscdimg: $oscdimgPath" "INFO"

# ============================================================================
# FIND BOOT FILES
# ============================================================================
$biosBootFile = "$isoPath\boot\etfsboot.com"
$uefiBootFile = "$isoPath\efi\microsoft\boot\efisys.bin"

# Alternative paths
if (-not (Test-Path $uefiBootFile)) {
    $uefiBootFile = "$isoPath\efi\microsoft\boot\efisys_noprompt.bin"
}
if (-not (Test-Path $uefiBootFile)) {
    $uefiBootFile = "$isoPath\boot\efisys.bin"
}

if (-not (Test-Path $biosBootFile) -or -not (Test-Path $uefiBootFile)) {
    Write-Step "Boot files not found!" "ERROR"
    Write-Step "BIOS: $biosBootFile exists: $(Test-Path $biosBootFile)" "INFO"
    Write-Step "UEFI: $uefiBootFile exists: $(Test-Path $uefiBootFile)" "INFO"
    exit 1
}

# ============================================================================
# CREATE ISO
# ============================================================================
Write-Step "Creating bootable ISO..." "INFO"

$isoFileName = $Config.General.IsoFileName
$outputIso = "$OutputPath\$isoFileName"

# Ensure output directory exists
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

# Remove existing ISO if present
if (Test-Path $outputIso) {
    Remove-Item $outputIso -Force
}

# Build the ISO with BIOS and UEFI boot support
$oscdimgArgs = @(
    "-m"                                           # Ignore maximum size limit
    "-o"                                           # Optimize storage
    "-u2"                                          # UDF file system
    "-udfver102"                                   # UDF version 1.02
    "-bootdata:2"                                  # Two boot entries
    "#p0,e,b`"$biosBootFile`""                     # BIOS boot
    "#pEF,e,b`"$uefiBootFile`""                    # UEFI boot
    "`"$isoPath`""                                 # Source path
    "`"$outputIso`""                               # Output ISO
)

$argString = $oscdimgArgs -join " "

Write-Step "Running: oscdimg $argString" "INFO"

# Execute oscdimg
$process = Start-Process -FilePath $oscdimgPath -ArgumentList $argString -Wait -PassThru -NoNewWindow

if ($process.ExitCode -eq 0 -and (Test-Path $outputIso)) {
    $isoSize = (Get-Item $outputIso).Length / 1GB
    $isoSizeFormatted = "{0:N2}" -f $isoSize

    Write-Step "ISO created successfully!" "SUCCESS"
    Write-Step "File: $outputIso" "INFO"
    Write-Step "Size: $isoSizeFormatted GB" "INFO"
}
else {
    Write-Step "ISO creation failed! Exit code: $($process.ExitCode)" "ERROR"
    exit 1
}

# ============================================================================
# CLEANUP SCRATCH FILES
# ============================================================================
Write-Step "Cleaning temporary files..." "INFO"

Remove-Item "$wimPath" -Force -ErrorAction SilentlyContinue
Remove-Item "$mountPath" -Recurse -Force -ErrorAction SilentlyContinue

Write-Step "ISO build complete" "SUCCESS"
