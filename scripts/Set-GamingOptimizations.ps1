#Requires -RunAsAdministrator
<#
.SYNOPSIS
    NeoTiny11 Gaming Builder - Gaming Optimizations
.DESCRIPTION
    Applies gaming-focused optimizations to the Windows image.
    Based on Atlas OS gaming tweaks and community best practices.
.PARAMETER MountPath
    Path to the mounted Windows image
.PARAMETER Config
    Configuration object with gaming settings
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$MountPath,

    [Parameter(Mandatory = $true)]
    [PSCustomObject]$Config
)

$ErrorActionPreference = "SilentlyContinue"

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

function Set-RegistryValue {
    param(
        [string]$Hive,
        [string]$Path,
        [string]$Name,
        [string]$Value,
        [string]$Type = "REG_DWORD"
    )

    $fullPath = "$Hive\$Path"
    reg add "$fullPath" /v "$Name" /t "$Type" /d "$Value" /f 2>$null | Out-Null
}

Write-Step "Applying gaming optimizations..." "INFO"

# Load offline registry hives
$hivesPath = "$MountPath\Windows\System32\config"
$softwareHive = "$hivesPath\SOFTWARE"
$systemHive = "$hivesPath\SYSTEM"
$defaultHive = "$hivesPath\DEFAULT"

Write-Step "Loading registry hives..." "INFO"
reg load "HKLM\OFFLINE_SOFTWARE" "$softwareHive" 2>$null
reg load "HKLM\OFFLINE_SYSTEM" "$systemHive" 2>$null
reg load "HKLM\OFFLINE_DEFAULT" "$defaultHive" 2>$null

# ============================================================================
# CPU OPTIMIZATIONS
# ============================================================================
Write-Step "Applying CPU optimizations..." "INFO"

if ($Config.Gaming.DisableCpuMitigations) {
    Write-Step "Disabling CPU mitigations (Spectre/Meltdown)..." "INFO"

    # Disable Spectre and Meltdown mitigations
    Set-RegistryValue -Hive "HKLM\OFFLINE_SYSTEM" -Path "ControlSet001\Control\Session Manager\Memory Management" `
        -Name "FeatureSettingsOverride" -Value "3"
    Set-RegistryValue -Hive "HKLM\OFFLINE_SYSTEM" -Path "ControlSet001\Control\Session Manager\Memory Management" `
        -Name "FeatureSettingsOverrideMask" -Value "3"

    Write-Step "CPU mitigations disabled (improves performance, reduces security)" "WARNING"
}

# Processor scheduling - Programs (foreground)
Set-RegistryValue -Hive "HKLM\OFFLINE_SYSTEM" -Path "ControlSet001\Control\PriorityControl" `
    -Name "Win32PrioritySeparation" -Value "38"

# Disable core parking
if ($Config.Gaming.DisableCoreParking) {
    Write-Step "Disabling core parking..." "INFO"
    Set-RegistryValue -Hive "HKLM\OFFLINE_SYSTEM" -Path "ControlSet001\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583" `
        -Name "ValueMin" -Value "0"
    Set-RegistryValue -Hive "HKLM\OFFLINE_SYSTEM" -Path "ControlSet001\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583" `
        -Name "ValueMax" -Value "0"
}

# ============================================================================
# GPU OPTIMIZATIONS
# ============================================================================
Write-Step "Applying GPU optimizations..." "INFO"

if ($Config.Gaming.EnableHardwareGpuScheduling) {
    Write-Step "Enabling hardware-accelerated GPU scheduling..." "INFO"
    Set-RegistryValue -Hive "HKLM\OFFLINE_SYSTEM" -Path "ControlSet001\Control\GraphicsDrivers" `
        -Name "HwSchMode" -Value "2"
}

if ($Config.Gaming.DisableFullscreenOptimizations) {
    Write-Step "Disabling fullscreen optimizations globally..." "INFO"
    Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Microsoft\Windows\DWM" `
        -Name "OverlayTestMode" -Value "5"
}

# Disable Game DVR (recording overhead)
if ($Config.Gaming.DisableGameDVR) {
    Write-Step "Disabling Game DVR recording overhead..." "INFO"
    Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Policies\Microsoft\Windows\GameDVR" `
        -Name "AllowGameDVR" -Value "0"
    Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Microsoft\Windows\CurrentVersion\GameDVR" `
        -Name "AppCaptureEnabled" -Value "0"
    Set-RegistryValue -Hive "HKLM\OFFLINE_DEFAULT" -Path "Software\Microsoft\Windows\CurrentVersion\GameDVR" `
        -Name "AppCaptureEnabled" -Value "0"
    Set-RegistryValue -Hive "HKLM\OFFLINE_DEFAULT" -Path "System\GameConfigStore" `
        -Name "GameDVR_Enabled" -Value "0"
}

# Enable Game Mode
if ($Config.Gaming.EnableGameMode) {
    Write-Step "Enabling Windows Game Mode..." "INFO"
    Set-RegistryValue -Hive "HKLM\OFFLINE_DEFAULT" -Path "Software\Microsoft\GameBar" `
        -Name "AutoGameModeEnabled" -Value "1"
    Set-RegistryValue -Hive "HKLM\OFFLINE_DEFAULT" -Path "Software\Microsoft\GameBar" `
        -Name "AllowAutoGameMode" -Value "1"
}

# ============================================================================
# NETWORK OPTIMIZATIONS (Gaming/Low Latency)
# ============================================================================
Write-Step "Applying network optimizations..." "INFO"

if ($Config.Gaming.OptimizeNetworkForGaming) {
    # Disable Nagle's Algorithm (reduces latency)
    if ($Config.Gaming.DisableNagleAlgorithm) {
        Write-Step "Disabling Nagle's algorithm..." "INFO"
        Set-RegistryValue -Hive "HKLM\OFFLINE_SYSTEM" -Path "ControlSet001\Services\Tcpip\Parameters\Interfaces" `
            -Name "TcpAckFrequency" -Value "1"
        Set-RegistryValue -Hive "HKLM\OFFLINE_SYSTEM" -Path "ControlSet001\Services\Tcpip\Parameters\Interfaces" `
            -Name "TCPNoDelay" -Value "1"
        Set-RegistryValue -Hive "HKLM\OFFLINE_SYSTEM" -Path "ControlSet001\Services\Tcpip\Parameters\Interfaces" `
            -Name "TcpDelAckTicks" -Value "0"
    }

    # Disable network throttling
    if ($Config.Gaming.DisableNetworkThrottling) {
        Write-Step "Disabling network throttling..." "INFO"
        Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" `
            -Name "NetworkThrottlingIndex" -Value "4294967295"
        Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" `
            -Name "SystemResponsiveness" -Value "0"
    }

    # TCP Optimizations
    Set-RegistryValue -Hive "HKLM\OFFLINE_SYSTEM" -Path "ControlSet001\Services\Tcpip\Parameters" `
        -Name "DefaultTTL" -Value "64"
    Set-RegistryValue -Hive "HKLM\OFFLINE_SYSTEM" -Path "ControlSet001\Services\Tcpip\Parameters" `
        -Name "MaxUserPort" -Value "65534"
    Set-RegistryValue -Hive "HKLM\OFFLINE_SYSTEM" -Path "ControlSet001\Services\Tcpip\Parameters" `
        -Name "TcpTimedWaitDelay" -Value "30"

    # Gaming-optimized QoS
    Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Policies\Microsoft\Windows\Psched" `
        -Name "NonBestEffortLimit" -Value "0"
}

# ============================================================================
# INPUT OPTIMIZATIONS (Mouse/Keyboard)
# ============================================================================
Write-Step "Applying input optimizations..." "INFO"

if ($Config.Gaming.OptimizeMouseKeyboard) {
    # Mouse responsiveness
    Set-RegistryValue -Hive "HKLM\OFFLINE_DEFAULT" -Path "Control Panel\Mouse" `
        -Name "MouseSensitivity" -Value "10" -Type "REG_SZ"
    Set-RegistryValue -Hive "HKLM\OFFLINE_DEFAULT" -Path "Control Panel\Mouse" `
        -Name "MouseSpeed" -Value "0" -Type "REG_SZ"
    Set-RegistryValue -Hive "HKLM\OFFLINE_DEFAULT" -Path "Control Panel\Mouse" `
        -Name "MouseThreshold1" -Value "0" -Type "REG_SZ"
    Set-RegistryValue -Hive "HKLM\OFFLINE_DEFAULT" -Path "Control Panel\Mouse" `
        -Name "MouseThreshold2" -Value "0" -Type "REG_SZ"

    # Keyboard responsiveness
    Set-RegistryValue -Hive "HKLM\OFFLINE_DEFAULT" -Path "Control Panel\Keyboard" `
        -Name "KeyboardDelay" -Value "0" -Type "REG_SZ"
    Set-RegistryValue -Hive "HKLM\OFFLINE_DEFAULT" -Path "Control Panel\Keyboard" `
        -Name "KeyboardSpeed" -Value "31" -Type "REG_SZ"

    # Disable pointer precision (acceleration)
    Set-RegistryValue -Hive "HKLM\OFFLINE_DEFAULT" -Path "Control Panel\Mouse" `
        -Name "MouseTrails" -Value "0" -Type "REG_SZ"
}

# ============================================================================
# POWER OPTIMIZATIONS
# ============================================================================
Write-Step "Applying power optimizations..." "INFO"

if ($Config.Gaming.SetHighPerformancePower) {
    # Set high performance power scheme as active
    Set-RegistryValue -Hive "HKLM\OFFLINE_SYSTEM" -Path "ControlSet001\Control\Power\User\PowerSchemes" `
        -Name "ActivePowerScheme" -Value "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" -Type "REG_SZ"

    # Disable USB selective suspend
    Set-RegistryValue -Hive "HKLM\OFFLINE_SYSTEM" -Path "ControlSet001\Control\Power\PowerSettings\2a737441-1930-4402-8d77-b2bebba308a3\48e6b7a6-50f5-4782-a5d4-53bb8f07e226" `
        -Name "Attributes" -Value "2"

    # Disable power throttling
    Set-RegistryValue -Hive "HKLM\OFFLINE_SYSTEM" -Path "ControlSet001\Control\Power\PowerThrottling" `
        -Name "PowerThrottlingOff" -Value "1"
}

# ============================================================================
# MEMORY OPTIMIZATIONS
# ============================================================================
Write-Step "Applying memory optimizations..." "INFO"

# Large system cache
Set-RegistryValue -Hive "HKLM\OFFLINE_SYSTEM" -Path "ControlSet001\Control\Session Manager\Memory Management" `
    -Name "LargeSystemCache" -Value "0"

# Disable paging executive
Set-RegistryValue -Hive "HKLM\OFFLINE_SYSTEM" -Path "ControlSet001\Control\Session Manager\Memory Management" `
    -Name "DisablePagingExecutive" -Value "1"

# Clear page file at shutdown (security + performance on next boot)
Set-RegistryValue -Hive "HKLM\OFFLINE_SYSTEM" -Path "ControlSet001\Control\Session Manager\Memory Management" `
    -Name "ClearPageFileAtShutdown" -Value "0"

# ============================================================================
# TIMER RESOLUTION (Important for gaming)
# ============================================================================
Write-Step "Optimizing timer resolution..." "INFO"

# Enable high resolution timer
Set-RegistryValue -Hive "HKLM\OFFLINE_SYSTEM" -Path "ControlSet001\Control\Session Manager\kernel" `
    -Name "GlobalTimerResolutionRequests" -Value "1"

# ============================================================================
# VISUAL EFFECTS (Performance focused)
# ============================================================================
Write-Step "Optimizing visual effects for performance..." "INFO"

# Disable animations
Set-RegistryValue -Hive "HKLM\OFFLINE_DEFAULT" -Path "Control Panel\Desktop" `
    -Name "UserPreferencesMask" -Value "9012078010000000" -Type "REG_BINARY"

# Disable transparency
Set-RegistryValue -Hive "HKLM\OFFLINE_DEFAULT" -Path "Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" `
    -Name "EnableTransparency" -Value "0"

# Reduce menu show delay
Set-RegistryValue -Hive "HKLM\OFFLINE_DEFAULT" -Path "Control Panel\Desktop" `
    -Name "MenuShowDelay" -Value "0" -Type "REG_SZ"

# ============================================================================
# BACKGROUND APPS
# ============================================================================
Write-Step "Disabling background apps..." "INFO"

Set-RegistryValue -Hive "HKLM\OFFLINE_DEFAULT" -Path "Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" `
    -Name "GlobalUserDisabled" -Value "1"
Set-RegistryValue -Hive "HKLM\OFFLINE_DEFAULT" -Path "Software\Microsoft\Windows\CurrentVersion\Search" `
    -Name "BackgroundAppGlobalToggle" -Value "0"

# ============================================================================
# MULTIMEDIA PRIORITY (Games)
# ============================================================================
Write-Step "Setting multimedia priority for games..." "INFO"

# Create Games profile with high priority
Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" `
    -Name "GPU Priority" -Value "8"
Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" `
    -Name "Priority" -Value "6"
Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" `
    -Name "Scheduling Category" -Value "High" -Type "REG_SZ"
Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" `
    -Name "SFIO Priority" -Value "High" -Type "REG_SZ"
Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" `
    -Name "Affinity" -Value "0"
Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" `
    -Name "Background Only" -Value "False" -Type "REG_SZ"
Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" `
    -Name "Clock Rate" -Value "10000"

# Unload registry hives
Write-Step "Unloading registry hives..." "INFO"
[gc]::Collect()
Start-Sleep -Seconds 2

reg unload "HKLM\OFFLINE_SOFTWARE" 2>$null
reg unload "HKLM\OFFLINE_SYSTEM" 2>$null
reg unload "HKLM\OFFLINE_DEFAULT" 2>$null

Write-Step "Gaming optimizations applied successfully" "SUCCESS"
