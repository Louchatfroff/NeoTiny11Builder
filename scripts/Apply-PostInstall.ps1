#Requires -RunAsAdministrator
<#
.SYNOPSIS
    NeoTiny11 Gaming Builder - Post-Install Optimizations
.DESCRIPTION
    Run this script AFTER installing Windows from NeoTiny11 ISO.
    Applies additional runtime optimizations that can't be done offline.
.NOTES
    Run as Administrator on the newly installed system
#>

$ErrorActionPreference = "SilentlyContinue"
$Host.UI.RawUI.WindowTitle = "NeoTiny11 Post-Install Optimizer"

function Write-Step {
    param([string]$Message, [string]$Status = "INFO")
    $color = switch ($Status) {
        "INFO"    { "Cyan" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR"   { "Red" }
        "STEP"    { "Magenta" }
        default   { "White" }
    }
    $prefix = switch ($Status) {
        "INFO"    { "[*]" }
        "SUCCESS" { "[+]" }
        "WARNING" { "[!]" }
        "ERROR"   { "[X]" }
        "STEP"    { "[>]" }
        default   { "[-]" }
    }
    Write-Host "$prefix $Message" -ForegroundColor $color
}

Clear-Host
Write-Host ""
Write-Host "  NeoTiny11 Post-Install Optimizer" -ForegroundColor Cyan
Write-Host "  =================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================================
# POWER PLAN
# ============================================================================
Write-Step "Setting up Ultimate Performance power plan..." "STEP"

# Enable hidden Ultimate Performance plan
powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null

# Get the GUID of Ultimate Performance plan
$ultimatePlan = powercfg -list | Select-String "Ultimate Performance" | ForEach-Object {
    if ($_ -match "([a-f0-9-]{36})") {
        $matches[1]
    }
}

if ($ultimatePlan) {
    powercfg -setactive $ultimatePlan
    Write-Step "Ultimate Performance plan activated" "SUCCESS"
} else {
    # Fall back to High Performance
    $highPerfPlan = powercfg -list | Select-String "High performance" | ForEach-Object {
        if ($_ -match "([a-f0-9-]{36})") {
            $matches[1]
        }
    }
    if ($highPerfPlan) {
        powercfg -setactive $highPerfPlan
        Write-Step "High Performance plan activated (Ultimate not available)" "WARNING"
    }
}

# ============================================================================
# NETWORK OPTIMIZATIONS
# ============================================================================
Write-Step "Applying network optimizations..." "STEP"

# Disable Nagle's Algorithm on all interfaces
$networkInterfaces = Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
foreach ($interface in $networkInterfaces) {
    Set-ItemProperty -Path $interface.PSPath -Name "TcpAckFrequency" -Value 1 -Type DWord -Force 2>$null
    Set-ItemProperty -Path $interface.PSPath -Name "TCPNoDelay" -Value 1 -Type DWord -Force 2>$null
    Set-ItemProperty -Path $interface.PSPath -Name "TcpDelAckTicks" -Value 0 -Type DWord -Force 2>$null
}

# Optimize network adapter settings
Get-NetAdapter | ForEach-Object {
    # Disable interrupt moderation (lower latency)
    Set-NetAdapterAdvancedProperty -Name $_.Name -RegistryKeyword "*InterruptModeration" -RegistryValue 0 -ErrorAction SilentlyContinue
    # Disable flow control
    Set-NetAdapterAdvancedProperty -Name $_.Name -RegistryKeyword "*FlowControl" -RegistryValue 0 -ErrorAction SilentlyContinue
}

# Disable NetBIOS over TCP/IP
$adapters = Get-WmiObject Win32_NetworkAdapterConfiguration -Filter "IPEnabled=True"
foreach ($adapter in $adapters) {
    $adapter.SetTcpipNetbios(2) | Out-Null
}

Write-Step "Network optimizations applied" "SUCCESS"

# ============================================================================
# TIMER RESOLUTION
# ============================================================================
Write-Step "Optimizing system timer resolution..." "STEP"

# Enable high-resolution timer globally
bcdedit /set useplatformtick yes 2>$null
bcdedit /set disabledynamictick yes 2>$null

Write-Step "Timer resolution optimized" "SUCCESS"

# ============================================================================
# GPU OPTIMIZATIONS
# ============================================================================
Write-Step "Applying GPU optimizations..." "STEP"

# Enable hardware-accelerated GPU scheduling if supported
$gpuScheduling = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "HwSchMode" -ErrorAction SilentlyContinue
if ($null -eq $gpuScheduling) {
    New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "HwSchMode" -Value 2 -PropertyType DWord -Force | Out-Null
    Write-Step "Hardware-accelerated GPU scheduling enabled" "SUCCESS"
} else {
    Write-Step "Hardware-accelerated GPU scheduling already configured" "INFO"
}

# ============================================================================
# DISABLE UNNECESSARY SCHEDULED TASKS
# ============================================================================
Write-Step "Disabling unnecessary scheduled tasks..." "STEP"

$tasksToDisable = @(
    "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser"
    "\Microsoft\Windows\Application Experience\ProgramDataUpdater"
    "\Microsoft\Windows\Autochk\Proxy"
    "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator"
    "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip"
    "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector"
    "\Microsoft\Windows\Feedback\Siuf\DmClient"
    "\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload"
    "\Microsoft\Windows\Windows Error Reporting\QueueReporting"
    "\Microsoft\Windows\Maps\MapsUpdateTask"
    "\Microsoft\Windows\Maps\MapsToastTask"
)

foreach ($task in $tasksToDisable) {
    schtasks /Change /TN "$task" /Disable 2>$null
}

Write-Step "Scheduled tasks optimized" "SUCCESS"

# ============================================================================
# MEMORY OPTIMIZATION
# ============================================================================
Write-Step "Configuring memory optimization..." "STEP"

# Disable memory compression (uses CPU, can hurt gaming)
Disable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue

# Set virtual memory to system managed (or configure manually for gaming)
$computerSystem = Get-WmiObject Win32_ComputerSystem -EnableAllPrivileges
$computerSystem.AutomaticManagedPagefile = $true
$computerSystem.Put() | Out-Null

Write-Step "Memory settings optimized" "SUCCESS"

# ============================================================================
# VISUAL EFFECTS OPTIMIZATION
# ============================================================================
Write-Step "Optimizing visual effects..." "STEP"

# Set to "Adjust for best performance" but keep font smoothing
$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
if (-not (Test-Path $regPath)) {
    New-Item -Path $regPath -Force | Out-Null
}
Set-ItemProperty -Path $regPath -Name "VisualFXSetting" -Value 2 -Type DWord

# Keep ClearType
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "FontSmoothing" -Value "2"
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "FontSmoothingType" -Value 2 -Type DWord

Write-Step "Visual effects optimized" "SUCCESS"

# ============================================================================
# ADDITIONAL GAMING TWEAKS
# ============================================================================
Write-Step "Applying additional gaming tweaks..." "STEP"

# Disable fullscreen optimizations globally
Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_FSEBehaviorMode" -Value 2 -Type DWord -Force 2>$null
Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_HonorUserFSEBehaviorMode" -Value 1 -Type DWord -Force 2>$null

# Enable Game Mode
Set-ItemProperty -Path "HKCU:\Software\Microsoft\GameBar" -Name "AutoGameModeEnabled" -Value 1 -Type DWord -Force 2>$null

Write-Step "Gaming tweaks applied" "SUCCESS"

# ============================================================================
# CLEANUP
# ============================================================================
Write-Step "Running cleanup..." "STEP"

# Clear temp files
Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue

# Clear prefetch (will rebuild with optimized data)
Remove-Item -Path "C:\Windows\Prefetch\*" -Force -ErrorAction SilentlyContinue

Write-Step "Cleanup complete" "SUCCESS"

# ============================================================================
# FINISH
# ============================================================================
Write-Host ""
Write-Host "  ================================================" -ForegroundColor Green
Write-Host "  Post-install optimization complete!" -ForegroundColor Green
Write-Host "  ================================================" -ForegroundColor Green
Write-Host ""
Write-Step "Some changes require a restart to take effect." "WARNING"
Write-Host ""

$restart = Read-Host "  Would you like to restart now? (Y/N)"
if ($restart -match "^[Yy]") {
    Write-Step "Restarting in 5 seconds..." "INFO"
    Start-Sleep -Seconds 5
    Restart-Computer -Force
}
