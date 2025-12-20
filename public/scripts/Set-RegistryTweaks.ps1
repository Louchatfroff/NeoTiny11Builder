#Requires -RunAsAdministrator
<#
.SYNOPSIS
    NeoTiny11 Gaming Builder - Registry Tweaks
.DESCRIPTION
    Applies privacy, telemetry, and installation bypass registry tweaks.
    Separate from gaming optimizations for clarity.
.PARAMETER MountPath
    Path to the mounted Windows image
.PARAMETER Config
    Configuration object with registry settings
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

function New-RegistryKey {
    param([string]$Path)
    reg add "$Path" /f 2>$null | Out-Null
}

Write-Step "Applying registry tweaks..." "INFO"

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
# WINDOWS 11 INSTALLATION BYPASSES
# ============================================================================
Write-Step "Applying Windows 11 installation bypasses..." "INFO"

if ($Config.Installation.BypassTPMCheck -or $Config.Installation.BypassSecureBootCheck -or
    $Config.Installation.BypassRAMCheck -or $Config.Installation.BypassCPUCheck) {

    New-RegistryKey -Path "HKLM\OFFLINE_SYSTEM\Setup\LabConfig"

    if ($Config.Installation.BypassTPMCheck) {
        Set-RegistryValue -Hive "HKLM\OFFLINE_SYSTEM" -Path "Setup\LabConfig" `
            -Name "BypassTPMCheck" -Value "1"
    }

    if ($Config.Installation.BypassSecureBootCheck) {
        Set-RegistryValue -Hive "HKLM\OFFLINE_SYSTEM" -Path "Setup\LabConfig" `
            -Name "BypassSecureBootCheck" -Value "1"
    }

    if ($Config.Installation.BypassRAMCheck) {
        Set-RegistryValue -Hive "HKLM\OFFLINE_SYSTEM" -Path "Setup\LabConfig" `
            -Name "BypassRAMCheck" -Value "1"
    }

    if ($Config.Installation.BypassCPUCheck) {
        Set-RegistryValue -Hive "HKLM\OFFLINE_SYSTEM" -Path "Setup\LabConfig" `
            -Name "BypassCPUCheck" -Value "1"
    }

    if ($Config.Installation.BypassStorageCheck) {
        Set-RegistryValue -Hive "HKLM\OFFLINE_SYSTEM" -Path "Setup\LabConfig" `
            -Name "BypassStorageCheck" -Value "1"
    }

    Write-Step "Hardware requirement bypasses applied" "SUCCESS"
}

# ============================================================================
# PRIVACY SETTINGS
# ============================================================================
Write-Step "Applying privacy tweaks..." "INFO"

if ($Config.Privacy.DisableTelemetry) {
    Write-Step "Disabling telemetry..." "INFO"

    # Main telemetry switch
    Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Policies\Microsoft\Windows\DataCollection" `
        -Name "AllowTelemetry" -Value "0"
    Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Microsoft\Windows\CurrentVersion\Policies\DataCollection" `
        -Name "AllowTelemetry" -Value "0"
    Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Microsoft\Windows\CurrentVersion\Policies\DataCollection" `
        -Name "MaxTelemetryAllowed" -Value "0"

    # Disable CEIP
    Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Policies\Microsoft\SQMClient\Windows" `
        -Name "CEIPEnable" -Value "0"

    # Disable Application Telemetry
    Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Policies\Microsoft\Windows\AppCompat" `
        -Name "AITEnable" -Value "0"
    Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Policies\Microsoft\Windows\AppCompat" `
        -Name "DisableInventory" -Value "1"
    Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Policies\Microsoft\Windows\AppCompat" `
        -Name "DisablePCA" -Value "1"
    Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Policies\Microsoft\Windows\AppCompat" `
        -Name "DisableUAR" -Value "1"
}

if ($Config.Privacy.DisableAdvertisingId) {
    Write-Step "Disabling advertising ID..." "INFO"
    Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Policies\Microsoft\Windows\AdvertisingInfo" `
        -Name "DisabledByGroupPolicy" -Value "1"
    Set-RegistryValue -Hive "HKLM\OFFLINE_DEFAULT" -Path "Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" `
        -Name "Enabled" -Value "0"
}

if ($Config.Privacy.DisableActivityHistory) {
    Write-Step "Disabling activity history..." "INFO"
    Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Policies\Microsoft\Windows\System" `
        -Name "EnableActivityFeed" -Value "0"
    Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Policies\Microsoft\Windows\System" `
        -Name "PublishUserActivities" -Value "0"
    Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Policies\Microsoft\Windows\System" `
        -Name "UploadUserActivities" -Value "0"
}

if ($Config.Privacy.DisableLocationTracking) {
    Write-Step "Disabling location tracking..." "INFO"
    Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Policies\Microsoft\Windows\LocationAndSensors" `
        -Name "DisableLocation" -Value "1"
    Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Policies\Microsoft\Windows\LocationAndSensors" `
        -Name "DisableLocationScripting" -Value "1"
    Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Policies\Microsoft\Windows\LocationAndSensors" `
        -Name "DisableWindowsLocationProvider" -Value "1"
}

if ($Config.Privacy.DisableDiagnosticData) {
    Write-Step "Disabling diagnostic data..." "INFO"
    Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Policies\Microsoft\Windows\Windows Error Reporting" `
        -Name "Disabled" -Value "1"
    Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Microsoft\Windows\Windows Error Reporting" `
        -Name "Disabled" -Value "1"
}

if ($Config.Privacy.DisableFeedbackRequests) {
    Write-Step "Disabling feedback requests..." "INFO"
    Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Policies\Microsoft\Windows\DataCollection" `
        -Name "DoNotShowFeedbackNotifications" -Value "1"
    Set-RegistryValue -Hive "HKLM\OFFLINE_DEFAULT" -Path "Software\Microsoft\Siuf\Rules" `
        -Name "NumberOfSIUFInPeriod" -Value "0"
}

# ============================================================================
# CONTENT DELIVERY / SUGGESTED APPS
# ============================================================================
Write-Step "Disabling suggested apps and content delivery..." "INFO"

# Disable Content Delivery Manager
Set-RegistryValue -Hive "HKLM\OFFLINE_DEFAULT" -Path "Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" `
    -Name "ContentDeliveryAllowed" -Value "0"
Set-RegistryValue -Hive "HKLM\OFFLINE_DEFAULT" -Path "Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" `
    -Name "FeatureManagementEnabled" -Value "0"
Set-RegistryValue -Hive "HKLM\OFFLINE_DEFAULT" -Path "Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" `
    -Name "OemPreInstalledAppsEnabled" -Value "0"
Set-RegistryValue -Hive "HKLM\OFFLINE_DEFAULT" -Path "Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" `
    -Name "PreInstalledAppsEnabled" -Value "0"
Set-RegistryValue -Hive "HKLM\OFFLINE_DEFAULT" -Path "Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" `
    -Name "PreInstalledAppsEverEnabled" -Value "0"
Set-RegistryValue -Hive "HKLM\OFFLINE_DEFAULT" -Path "Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" `
    -Name "SilentInstalledAppsEnabled" -Value "0"
Set-RegistryValue -Hive "HKLM\OFFLINE_DEFAULT" -Path "Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" `
    -Name "SoftLandingEnabled" -Value "0"
Set-RegistryValue -Hive "HKLM\OFFLINE_DEFAULT" -Path "Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" `
    -Name "SubscribedContentEnabled" -Value "0"
Set-RegistryValue -Hive "HKLM\OFFLINE_DEFAULT" -Path "Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" `
    -Name "SystemPaneSuggestionsEnabled" -Value "0"

# Disable specific subscribed content
$subscribedContent = @(
    "SubscribedContent-310093Enabled"
    "SubscribedContent-314559Enabled"
    "SubscribedContent-314563Enabled"
    "SubscribedContent-338387Enabled"
    "SubscribedContent-338388Enabled"
    "SubscribedContent-338389Enabled"
    "SubscribedContent-338393Enabled"
    "SubscribedContent-353694Enabled"
    "SubscribedContent-353696Enabled"
    "SubscribedContent-353698Enabled"
)

foreach ($content in $subscribedContent) {
    Set-RegistryValue -Hive "HKLM\OFFLINE_DEFAULT" -Path "Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" `
        -Name $content -Value "0"
}

# ============================================================================
# WINDOWS CHAT / TEAMS
# ============================================================================
Write-Step "Disabling Windows Chat / Teams auto-install..." "INFO"

Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Policies\Microsoft\Windows\Windows Chat" `
    -Name "ChatIcon" -Value "3"
Set-RegistryValue -Hive "HKLM\OFFLINE_DEFAULT" -Path "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
    -Name "TaskbarMn" -Value "0"

# ============================================================================
# WINDOWS COPILOT
# ============================================================================
Write-Step "Disabling Windows Copilot..." "INFO"

Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Policies\Microsoft\Windows\WindowsCopilot" `
    -Name "TurnOffWindowsCopilot" -Value "1"
Set-RegistryValue -Hive "HKLM\OFFLINE_DEFAULT" -Path "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
    -Name "ShowCopilotButton" -Value "0"

# ============================================================================
# WIDGETS
# ============================================================================
Write-Step "Disabling Widgets..." "INFO"

Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Policies\Microsoft\Dsh" `
    -Name "AllowNewsAndInterests" -Value "0"
Set-RegistryValue -Hive "HKLM\OFFLINE_DEFAULT" -Path "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
    -Name "TaskbarDa" -Value "0"

# ============================================================================
# STARTUP EXPERIENCE
# ============================================================================
Write-Step "Optimizing startup experience..." "INFO"

# Disable first logon animation
Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Microsoft\Windows\CurrentVersion\Policies\System" `
    -Name "EnableFirstLogonAnimation" -Value "0"

# Disable "Let's finish setting up" nag
Set-RegistryValue -Hive "HKLM\OFFLINE_DEFAULT" -Path "Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement" `
    -Name "ScoobeSystemSettingEnabled" -Value "0"

# Disable reserved storage
Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Microsoft\Windows\CurrentVersion\ReserveManager" `
    -Name "ShippedWithReserves" -Value "0"
Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Microsoft\Windows\CurrentVersion\ReserveManager" `
    -Name "PassedPolicy" -Value "0"

# ============================================================================
# EXPLORER TWEAKS
# ============================================================================
Write-Step "Applying Explorer tweaks..." "INFO"

# Show file extensions
Set-RegistryValue -Hive "HKLM\OFFLINE_DEFAULT" -Path "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
    -Name "HideFileExt" -Value "0"

# Show hidden files
Set-RegistryValue -Hive "HKLM\OFFLINE_DEFAULT" -Path "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
    -Name "Hidden" -Value "1"

# Disable recent files in Quick Access
Set-RegistryValue -Hive "HKLM\OFFLINE_DEFAULT" -Path "Software\Microsoft\Windows\CurrentVersion\Explorer" `
    -Name "ShowRecent" -Value "0"
Set-RegistryValue -Hive "HKLM\OFFLINE_DEFAULT" -Path "Software\Microsoft\Windows\CurrentVersion\Explorer" `
    -Name "ShowFrequent" -Value "0"

# Open File Explorer to "This PC"
Set-RegistryValue -Hive "HKLM\OFFLINE_DEFAULT" -Path "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
    -Name "LaunchTo" -Value "1"

# ============================================================================
# DISABLE BITLOCKER DEVICE ENCRYPTION
# ============================================================================
Write-Step "Disabling automatic BitLocker device encryption..." "INFO"

Set-RegistryValue -Hive "HKLM\OFFLINE_SYSTEM" -Path "ControlSet001\Control\BitLocker" `
    -Name "PreventDeviceEncryption" -Value "1"

# ============================================================================
# CONTEXT MENU (Windows 11 - Show More Options by default)
# ============================================================================
Write-Step "Enabling classic context menu..." "INFO"

New-RegistryKey -Path "HKLM\OFFLINE_DEFAULT\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"

# ============================================================================
# PREVENT DEVHOME AND OUTLOOK REINSTALL
# ============================================================================
Write-Step "Preventing DevHome and Outlook reinstall..." "INFO"

Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\DevHomeUpdate" `
    -Name "workCompleted" -Value "1"
Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\OutlookUpdate" `
    -Name "workCompleted" -Value "1"
New-RegistryKey -Path "HKLM\OFFLINE_SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Orchestrator\UScheduler\DevHomeUpdate"
New-RegistryKey -Path "HKLM\OFFLINE_SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Orchestrator\UScheduler\OutlookUpdate"

# ============================================================================
# DISABLE WINDOWS UPDATE COMPLETELY
# ============================================================================
Write-Step "Disabling Windows Update..." "INFO"

# Disable Windows Update via Group Policy
New-RegistryKey -Path "HKLM\OFFLINE_SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
New-RegistryKey -Path "HKLM\OFFLINE_SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"

# Disable automatic updates
Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Policies\Microsoft\Windows\WindowsUpdate\AU" `
    -Name "NoAutoUpdate" -Value "1"
Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Policies\Microsoft\Windows\WindowsUpdate\AU" `
    -Name "AUOptions" -Value "1"
Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Policies\Microsoft\Windows\WindowsUpdate\AU" `
    -Name "NoAutoRebootWithLoggedOnUsers" -Value "1"

# Disable Windows Update entirely
Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Policies\Microsoft\Windows\WindowsUpdate" `
    -Name "DisableWindowsUpdateAccess" -Value "1"
Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Policies\Microsoft\Windows\WindowsUpdate" `
    -Name "DoNotConnectToWindowsUpdateInternetLocations" -Value "1"
Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Policies\Microsoft\Windows\WindowsUpdate" `
    -Name "SetDisableUXWUAccess" -Value "1"

# Disable driver updates via Windows Update
Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Policies\Microsoft\Windows\WindowsUpdate" `
    -Name "ExcludeWUDriversInQualityUpdate" -Value "1"
Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Microsoft\Windows\CurrentVersion\DriverSearching" `
    -Name "SearchOrderConfig" -Value "0"
Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Policies\Microsoft\Windows\DriverSearching" `
    -Name "DriverUpdateWizardWuSearchEnabled" -Value "0"

# Disable Update Orchestrator scheduled tasks via registry
Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Microsoft\WindowsUpdate\UX\Settings" `
    -Name "HideMCTLink" -Value "1"
Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Microsoft\WindowsUpdate\UX\Settings" `
    -Name "UxOption" -Value "1"

# Disable "Why did my PC restart" notification
Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" `
    -Name "AUOptions" -Value "1"
Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" `
    -Name "EnableFeaturedSoftware" -Value "0"

# Disable Windows Update Medic Service reactivation
New-RegistryKey -Path "HKLM\OFFLINE_SYSTEM\ControlSet001\Services\WaaSMedicSvc"
Set-RegistryValue -Hive "HKLM\OFFLINE_SYSTEM" -Path "ControlSet001\Services\WaaSMedicSvc" `
    -Name "Start" -Value "4"

# Disable Update Health Tools
Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Policies\Microsoft\Windows\WindowsUpdate" `
    -Name "ManagePreviewBuilds" -Value "1"
Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Policies\Microsoft\Windows\WindowsUpdate" `
    -Name "ManagePreviewBuildsPolicyValue" -Value "0"

# Prevent Store from auto-updating apps
Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Policies\Microsoft\WindowsStore" `
    -Name "AutoDownload" -Value "2"

Write-Step "Windows Update disabled" "SUCCESS"

# ============================================================================
# DISABLE RESTART NOTIFICATIONS AND RECOVERY
# ============================================================================
Write-Step "Disabling restart notifications..." "INFO"

# Disable "Why did my PC restart" / Shutdown Event Tracker
New-RegistryKey -Path "HKLM\OFFLINE_SOFTWARE\Policies\Microsoft\Windows NT\Reliability"
Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Policies\Microsoft\Windows NT\Reliability" `
    -Name "ShutdownReasonOn" -Value "0"
Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Policies\Microsoft\Windows NT\Reliability" `
    -Name "ShutdownReasonUI" -Value "0"
New-RegistryKey -Path "HKLM\OFFLINE_SOFTWARE\Microsoft\Windows\CurrentVersion\Reliability"
Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Microsoft\Windows\CurrentVersion\Reliability" `
    -Name "ShutdownReasonUI" -Value "0"

# Disable Automatic Restart Sign-on (ARSO)
Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Microsoft\Windows\CurrentVersion\Policies\System" `
    -Name "DisableAutomaticRestartSignOn" -Value "1"

# Disable restart required notifications
Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Policies\Microsoft\Windows\WindowsUpdate" `
    -Name "SetAutoRestartNotificationDisable" -Value "1"
Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Policies\Microsoft\Windows\WindowsUpdate\AU" `
    -Name "NoAUShutdownOption" -Value "1"
Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Policies\Microsoft\Windows\WindowsUpdate\AU" `
    -Name "NoAUAsDefaultShutdownOption" -Value "1"

# Disable Windows Error Reporting (can trigger restart dialogs)
Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Policies\Microsoft\Windows\Windows Error Reporting" `
    -Name "Disabled" -Value "1"
Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Policies\Microsoft\Windows\Windows Error Reporting" `
    -Name "DontSendAdditionalData" -Value "1"
Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Policies\Microsoft\Windows\Windows Error Reporting" `
    -Name "LoggingDisabled" -Value "1"
Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Policies\Microsoft\Windows\Windows Error Reporting" `
    -Name "DontShowUI" -Value "1"

# Disable Automatic Maintenance (can trigger restart prompts)
New-RegistryKey -Path "HKLM\OFFLINE_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance"
Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance" `
    -Name "MaintenanceDisabled" -Value "1"

# Disable restart after BSOD
Set-RegistryValue -Hive "HKLM\OFFLINE_SYSTEM" -Path "ControlSet001\Control\CrashControl" `
    -Name "AutoReboot" -Value "0"

# Disable Delivery Optimization
New-RegistryKey -Path "HKLM\OFFLINE_SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization"
Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Policies\Microsoft\Windows\DeliveryOptimization" `
    -Name "DODownloadMode" -Value "0"

# Disable Update Notification Level
Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Policies\Microsoft\Windows\WindowsUpdate" `
    -Name "SetUpdateNotificationLevel" -Value "1"
Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Policies\Microsoft\Windows\WindowsUpdate" `
    -Name "UpdateNotificationLevel" -Value "2"

# Disable Reboot Notifications
Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Policies\Microsoft\Windows\WindowsUpdate" `
    -Name "SetAutoRestartDeadline" -Value "0"
Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Policies\Microsoft\Windows\WindowsUpdate" `
    -Name "SetEngagedRestartTransitionSchedule" -Value "0"
Set-RegistryValue -Hive "HKLM\OFFLINE_SOFTWARE" -Path "Policies\Microsoft\Windows\WindowsUpdate" `
    -Name "SetRestartWarningSchd" -Value "0"

Write-Step "Restart notifications disabled" "SUCCESS"

# Unload registry hives
Write-Step "Unloading registry hives..." "INFO"
[gc]::Collect()
Start-Sleep -Seconds 2

reg unload "HKLM\OFFLINE_SOFTWARE" 2>$null
reg unload "HKLM\OFFLINE_SYSTEM" 2>$null
reg unload "HKLM\OFFLINE_DEFAULT" 2>$null

Write-Step "Registry tweaks applied successfully" "SUCCESS"
