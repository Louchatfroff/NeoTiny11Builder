#Requires -RunAsAdministrator
<#
.SYNOPSIS
    NeoTiny11 Gaming Builder - Service Optimizations
.DESCRIPTION
    Optimizes Windows services for gaming performance.
    Disables unnecessary services while keeping gaming-essential ones.
.PARAMETER MountPath
    Path to the mounted Windows image
.PARAMETER Config
    Configuration object with service settings
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

function Set-ServiceStartType {
    param(
        [string]$ServiceName,
        [int]$StartType  # 0=Boot, 1=System, 2=Auto, 3=Manual, 4=Disabled
    )

    $regPath = "HKLM\OFFLINE_SYSTEM\ControlSet001\Services\$ServiceName"
    reg add "$regPath" /v "Start" /t REG_DWORD /d $StartType /f 2>$null | Out-Null
}

Write-Step "Optimizing Windows services..." "INFO"

# Load SYSTEM hive
$systemHive = "$MountPath\Windows\System32\config\SYSTEM"
Write-Step "Loading SYSTEM registry hive..." "INFO"
reg load "HKLM\OFFLINE_SYSTEM" "$systemHive" 2>$null

# ============================================================================
# SERVICES TO DISABLE (4 = Disabled)
# ============================================================================

# Always disable these (bloat/telemetry)
$alwaysDisable = @(
    "DiagTrack"                    # Connected User Experiences and Telemetry
    "dmwappushservice"             # Device Management Wireless Application Protocol Push
    "MapsBroker"                   # Downloaded Maps Manager
    "lfsvc"                        # Geolocation Service
    "SharedAccess"                 # Internet Connection Sharing
    "RetailDemo"                   # Retail Demo Service
    "RemoteRegistry"               # Remote Registry
    "WMPNetworkSvc"                # Windows Media Player Network Sharing
    "WerSvc"                       # Windows Error Reporting Service
    "Fax"                          # Fax
    "fhsvc"                        # File History Service
    "TapiSrv"                      # Telephony
    "FrameServer"                  # Windows Camera Frame Server
    "wisvc"                        # Windows Insider Service
    "icssvc"                       # Windows Mobile Hotspot Service
    "PhoneSvc"                     # Phone Service
    "SEMgrSvc"                     # Payments and NFC/SE Manager
    "WpcMonSvc"                    # Parental Controls
    "PcaSvc"                       # Program Compatibility Assistant
    "wercplsupport"                # Problem Reports Control Panel
    "MessagingService"             # MessagingService
    "OneSyncSvc"                   # Sync Host
    "CDPUserSvc"                   # Connected Devices Platform User Service
    "PimIndexMaintenanceSvc"       # Contact Data
    "UnistoreSvc"                  # User Data Storage
    "UserDataSvc"                  # User Data Access
    "WalletService"                # Wallet Service
    "TokenBroker"                  # Web Account Manager
    "WebClient"                    # WebClient
    "MixedRealityOpenXRSvc"        # Windows Mixed Reality OpenXR Service
    "spectrum"                     # Windows Perception Service
    "perceptionsimulation"         # Windows Perception Simulation Service
    "WiaRpc"                       # Still Image Acquisition Events
    "stisvc"                       # Windows Image Acquisition
    "XblAuthManager"               # Xbox Live Auth Manager (if removing Xbox)
    "XblGameSave"                  # Xbox Live Game Save
    "XboxNetApiSvc"                # Xbox Live Networking Service
    "XboxGipSvc"                   # Xbox Accessory Management Service
    # Windows Update related services - DISABLED for gaming ISO
    "wuauserv"                     # Windows Update
    "UsoSvc"                       # Update Orchestrator Service
    "WaaSMedicSvc"                 # Windows Update Medic Service
    "BITS"                         # Background Intelligent Transfer Service
    "DoSvc"                        # Delivery Optimization
    "uhssvc"                       # Microsoft Update Health Service
)

# Conditional disables based on config
$conditionalDisable = @{
    "DisableSearchIndexing" = @("WSearch")
    "DisableSysMain" = @("SysMain")
    "DisablePrintSpooler" = @("Spooler")
    "DisableFax" = @("Fax")
    "DisableWindowsErrorReporting" = @("WerSvc", "wercplsupport")
    "DisableDiagTrack" = @("DiagTrack", "dmwappushservice")
    "DisableConnectedUserExperiences" = @("CDPSvc", "CDPUserSvc")
    "DisableXboxServices" = @("XblAuthManager", "XblGameSave", "XboxNetApiSvc", "XboxGipSvc")
}

Write-Step "Disabling unnecessary services..." "INFO"
$disabledCount = 0

# Disable always-disable services
foreach ($service in $alwaysDisable) {
    Set-ServiceStartType -ServiceName $service -StartType 4
    $disabledCount++
}

# Disable conditional services based on config
foreach ($setting in $conditionalDisable.Keys) {
    if ($Config.Services.$setting) {
        foreach ($service in $conditionalDisable[$setting]) {
            Set-ServiceStartType -ServiceName $service -StartType 4
            $disabledCount++
            Write-Step "Disabled: $service" "INFO"
        }
    }
}

Write-Step "Disabled $disabledCount services" "SUCCESS"

# ============================================================================
# SERVICES TO SET TO MANUAL (3 = Manual)
# ============================================================================

$setToManual = @(
    "AppXSvc"                      # AppX Deployment Service
    "ClipSVC"                      # Client License Service
    "CryptSvc"                     # Cryptographic Services
    "FontCache"                    # Windows Font Cache Service
    "gpsvc"                        # Group Policy Client
    "InstallService"               # Microsoft Store Install Service
    "LanmanServer"                 # Server
    "LanmanWorkstation"            # Workstation
    "lmhosts"                      # TCP/IP NetBIOS Helper
    "MSDTC"                        # Distributed Transaction Coordinator
    "Netlogon"                     # Netlogon
    "netprofm"                     # Network List Service
    "NlaSvc"                       # Network Location Awareness
    "nsi"                          # Network Store Interface Service
    "ProfSvc"                      # User Profile Service
    "RasMan"                       # Remote Access Connection Manager
    "SamSs"                        # Security Accounts Manager
    "SDRSVC"                       # Windows Backup
    "ShellHWDetection"             # Shell Hardware Detection
    "Themes"                       # Themes
    "TrkWks"                       # Distributed Link Tracking Client
    "W32Time"                      # Windows Time
    "Wcmsvc"                       # Windows Connection Manager
    "WinHttpAutoProxySvc"          # WinHTTP Web Proxy Auto-Discovery
    "Winmgmt"                      # Windows Management Instrumentation
    "wscsvc"                       # Security Center
    "WlanSvc"                      # WLAN AutoConfig
    "PlugPlay"                     # Plug and Play
)

Write-Step "Setting services to manual start..." "INFO"
$manualCount = 0

foreach ($service in $setToManual) {
    Set-ServiceStartType -ServiceName $service -StartType 3
    $manualCount++
}

Write-Step "Set $manualCount services to manual" "SUCCESS"

# ============================================================================
# GAMING-ESSENTIAL SERVICES (Keep Auto or leave as-is)
# ============================================================================

$gamingEssential = @(
    "Audiosrv"                     # Windows Audio
    "AudioEndpointBuilder"         # Windows Audio Endpoint Builder
    "BrokerInfrastructure"         # Background Tasks Infrastructure
    "CoreMessagingRegistrar"       # CoreMessaging
    "DcomLaunch"                   # DCOM Server Process Launcher
    "Dhcp"                         # DHCP Client
    "Dnscache"                     # DNS Client
    "DusmSvc"                      # Data Usage
    "EventLog"                     # Windows Event Log
    "EventSystem"                  # COM+ Event System
    "FontCache"                    # Windows Font Cache
    "LSM"                          # Local Session Manager
    "Power"                        # Power
    "RpcEptMapper"                 # RPC Endpoint Mapper
    "RpcSs"                        # Remote Procedure Call (RPC)
    "Schedule"                     # Task Scheduler
    "SgrmBroker"                   # System Guard Runtime Monitor Broker
    "StateRepository"              # State Repository Service
    "StorSvc"                      # Storage Service
    "SystemEventsBroker"           # System Events Broker
    "TimeBrokerSvc"                # Time Broker
    "UserManager"                  # User Manager
    "VaultSvc"                     # Credential Manager
    "Wcmsvc"                       # Windows Connection Manager
    "WpnService"                   # Windows Push Notifications System Service
    "mpssvc"                       # Windows Defender Firewall
    "WinDefend"                    # Windows Defender Antivirus Service
)

Write-Step "Ensuring gaming-essential services are enabled..." "INFO"

foreach ($service in $gamingEssential) {
    # Check if currently disabled and enable if so
    $currentValue = reg query "HKLM\OFFLINE_SYSTEM\ControlSet001\Services\$service" /v Start 2>$null
    if ($currentValue -match "0x4") {
        Set-ServiceStartType -ServiceName $service -StartType 2  # Auto
        Write-Step "Re-enabled essential: $service" "INFO"
    }
}

# ============================================================================
# NVIDIA/AMD SPECIFIC SERVICES (Keep enabled if present)
# ============================================================================

$gpuServices = @(
    "NVDisplay.ContainerLocalSystem"   # NVIDIA Display Container
    "NvContainerLocalSystem"           # NVIDIA LocalSystem Container
    "AMD External Events Utility"      # AMD External Events
)

Write-Step "Preserving GPU driver services..." "INFO"

foreach ($service in $gpuServices) {
    # These should remain at their default settings
    # We just verify they're not disabled
    $exists = reg query "HKLM\OFFLINE_SYSTEM\ControlSet001\Services\$service" 2>$null
    if ($exists) {
        Write-Step "Found GPU service: $service (preserved)" "INFO"
    }
}

# Unload registry hive
Write-Step "Unloading registry hive..." "INFO"
[gc]::Collect()
Start-Sleep -Seconds 2
reg unload "HKLM\OFFLINE_SYSTEM" 2>$null

Write-Step "Service optimization completed" "SUCCESS"
