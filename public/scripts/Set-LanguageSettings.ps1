#Requires -RunAsAdministrator
<#
.SYNOPSIS
    NeoTiny11 Gaming Builder - Language & Keyboard Settings
.DESCRIPTION
    Configures language and keyboard layouts based on user selection.
    French: French language with AZERTY + QWERTY layouts
    English: English US language with QWERTY + AZERTY layouts
.PARAMETER MountPath
    Path to the mounted Windows image
.PARAMETER Language
    Selected language (FR or EN)
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$MountPath,

    [Parameter(Mandatory = $true)]
    [ValidateSet("FR", "EN")]
    [string]$Language
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

Write-Step "Configuring language settings for: $Language" "INFO"

# Load registry hives
$hivesPath = "$MountPath\Windows\System32\config"
$softwareHive = "$hivesPath\SOFTWARE"
$systemHive = "$hivesPath\SYSTEM"
$defaultHive = "$hivesPath\DEFAULT"

Write-Step "Loading registry hives..." "INFO"
reg load "HKLM\OFFLINE_SOFTWARE" "$softwareHive" 2>$null
reg load "HKLM\OFFLINE_SYSTEM" "$systemHive" 2>$null
reg load "HKLM\OFFLINE_DEFAULT" "$defaultHive" 2>$null

# Language configuration based on selection
if ($Language -eq "FR") {
    Write-Step "Setting French as primary language..." "INFO"

    # French locale settings
    $primaryLanguage = "fr-FR"
    $primaryLocale = "0000040c"  # French (France)
    $secondaryLocale = "00000409"  # US QWERTY as secondary
    $primaryKeyboard = "0000040c"  # AZERTY French
    $secondaryKeyboard = "00000409"  # QWERTY US
    $geoId = "84"  # France
    $timeZone = "Romance Standard Time"

    # Keyboard layout order: AZERTY first, then QWERTY
    $keyboardLayouts = "0000040c;00000409"
    $inputLocales = "040c:0000040c;0409:00000409"

} else {
    Write-Step "Setting English (US) as primary language..." "INFO"

    # English US locale settings
    $primaryLanguage = "en-US"
    $primaryLocale = "00000409"  # English (US)
    $secondaryLocale = "0000040c"  # French AZERTY as secondary
    $primaryKeyboard = "00000409"  # QWERTY US
    $secondaryKeyboard = "0000040c"  # AZERTY French
    $geoId = "244"  # United States
    $timeZone = "Pacific Standard Time"

    # Keyboard layout order: QWERTY first, then AZERTY
    $keyboardLayouts = "00000409;0000040c"
    $inputLocales = "0409:00000409;040c:0000040c"
}

# ============================================================================
# SYSTEM LOCALE SETTINGS
# ============================================================================
Write-Step "Applying system locale settings..." "INFO"

# Set system locale
reg add "HKLM\OFFLINE_SYSTEM\ControlSet001\Control\Nls\Language" /v "Default" /t REG_SZ /d $primaryLocale /f 2>$null
reg add "HKLM\OFFLINE_SYSTEM\ControlSet001\Control\Nls\Language" /v "InstallLanguage" /t REG_SZ /d $primaryLocale /f 2>$null

# Set locale settings
reg add "HKLM\OFFLINE_SYSTEM\ControlSet001\Control\Nls\Locale" /v "(Default)" /t REG_SZ /d $primaryLocale /f 2>$null

# ============================================================================
# USER LOCALE SETTINGS (DEFAULT USER)
# ============================================================================
Write-Step "Applying user locale settings..." "INFO"

# International settings for default user
reg add "HKLM\OFFLINE_DEFAULT\Control Panel\International" /v "Locale" /t REG_SZ /d $primaryLocale /f 2>$null
reg add "HKLM\OFFLINE_DEFAULT\Control Panel\International" /v "LocaleName" /t REG_SZ /d $primaryLanguage /f 2>$null
reg add "HKLM\OFFLINE_DEFAULT\Control Panel\International" /v "sLanguage" /t REG_SZ /d $(if ($Language -eq "FR") { "FRA" } else { "ENU" }) /f 2>$null
reg add "HKLM\OFFLINE_DEFAULT\Control Panel\International" /v "sCountry" /t REG_SZ /d $(if ($Language -eq "FR") { "France" } else { "United States" }) /f 2>$null

# Geo settings
reg add "HKLM\OFFLINE_DEFAULT\Control Panel\International\Geo" /v "Nation" /t REG_SZ /d $geoId /f 2>$null
reg add "HKLM\OFFLINE_DEFAULT\Control Panel\International\Geo" /v "Name" /t REG_SZ /d $(if ($Language -eq "FR") { "FR" } else { "US" }) /f 2>$null

# ============================================================================
# KEYBOARD LAYOUT SETTINGS
# ============================================================================
Write-Step "Configuring keyboard layouts..." "INFO"

# Keyboard layout preload (both layouts available)
reg add "HKLM\OFFLINE_DEFAULT\Keyboard Layout\Preload" /v "1" /t REG_SZ /d $primaryKeyboard /f 2>$null
reg add "HKLM\OFFLINE_DEFAULT\Keyboard Layout\Preload" /v "2" /t REG_SZ /d $secondaryKeyboard /f 2>$null

# Remove any other preloaded keyboards (keep only 2)
reg delete "HKLM\OFFLINE_DEFAULT\Keyboard Layout\Preload" /v "3" /f 2>$null
reg delete "HKLM\OFFLINE_DEFAULT\Keyboard Layout\Preload" /v "4" /f 2>$null
reg delete "HKLM\OFFLINE_DEFAULT\Keyboard Layout\Preload" /v "5" /f 2>$null

# ============================================================================
# LANGUAGE LIST SETTINGS
# ============================================================================
Write-Step "Setting language list..." "INFO"

# User language list
if ($Language -eq "FR") {
    reg add "HKLM\OFFLINE_DEFAULT\Control Panel\International\User Profile" /v "Languages" /t REG_MULTI_SZ /d "fr-FR\0en-US" /f 2>$null
    reg add "HKLM\OFFLINE_DEFAULT\Control Panel\International\User Profile\fr-FR" /v "CachedLanguageName" /t REG_SZ /d "@Winlangdb.dll,-1036" /f 2>$null
    reg add "HKLM\OFFLINE_DEFAULT\Control Panel\International\User Profile\fr-FR" /v "0000040C" /t REG_DWORD /d 1 /f 2>$null
    reg add "HKLM\OFFLINE_DEFAULT\Control Panel\International\User Profile\en-US" /v "CachedLanguageName" /t REG_SZ /d "@Winlangdb.dll,-1033" /f 2>$null
    reg add "HKLM\OFFLINE_DEFAULT\Control Panel\International\User Profile\en-US" /v "00000409" /t REG_DWORD /d 2 /f 2>$null
} else {
    reg add "HKLM\OFFLINE_DEFAULT\Control Panel\International\User Profile" /v "Languages" /t REG_MULTI_SZ /d "en-US\0fr-FR" /f 2>$null
    reg add "HKLM\OFFLINE_DEFAULT\Control Panel\International\User Profile\en-US" /v "CachedLanguageName" /t REG_SZ /d "@Winlangdb.dll,-1033" /f 2>$null
    reg add "HKLM\OFFLINE_DEFAULT\Control Panel\International\User Profile\en-US" /v "00000409" /t REG_DWORD /d 1 /f 2>$null
    reg add "HKLM\OFFLINE_DEFAULT\Control Panel\International\User Profile\fr-FR" /v "CachedLanguageName" /t REG_SZ /d "@Winlangdb.dll,-1036" /f 2>$null
    reg add "HKLM\OFFLINE_DEFAULT\Control Panel\International\User Profile\fr-FR" /v "0000040C" /t REG_DWORD /d 2 /f 2>$null
}

# ============================================================================
# OOBE SETTINGS (First-run experience)
# ============================================================================
Write-Step "Configuring OOBE language settings..." "INFO"

reg add "HKLM\OFFLINE_SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE" /v "SetupDisplayedLanguage" /t REG_SZ /d $primaryLanguage /f 2>$null

# ============================================================================
# TIMEZONE SETTINGS
# ============================================================================
Write-Step "Setting timezone to: $timeZone" "INFO"

reg add "HKLM\OFFLINE_SYSTEM\ControlSet001\Control\TimeZoneInformation" /v "TimeZoneKeyName" /t REG_SZ /d $timeZone /f 2>$null

# Unload registry hives
Write-Step "Unloading registry hives..." "INFO"
[gc]::Collect()
Start-Sleep -Seconds 2

reg unload "HKLM\OFFLINE_SOFTWARE" 2>$null
reg unload "HKLM\OFFLINE_SYSTEM" 2>$null
reg unload "HKLM\OFFLINE_DEFAULT" 2>$null

# ============================================================================
# CREATE LANGUAGE XML FOR DISM
# ============================================================================
Write-Step "Creating language configuration file..." "INFO"

$langXmlPath = "$MountPath\Windows\Temp\lang.xml"

if ($Language -eq "FR") {
    $langXmlContent = @"
<gs:GlobalizationServices xmlns:gs="urn:longhornGlobalizationUnattend">
    <gs:UserList>
        <gs:User UserID="Current" CopySettingsToDefaultUserAcct="true" CopySettingsToSystemAcct="true"/>
    </gs:UserList>
    <gs:UserLocale>
        <gs:Locale Name="fr-FR" SetAsCurrent="true"/>
    </gs:UserLocale>
    <gs:InputPreferences>
        <gs:InputLanguageID Action="add" ID="040c:0000040c" Default="true"/>
        <gs:InputLanguageID Action="add" ID="0409:00000409"/>
    </gs:InputPreferences>
    <gs:MUILanguagePreferences>
        <gs:MUILanguage Value="fr-FR"/>
    </gs:MUILanguagePreferences>
    <gs:SystemLocale Name="fr-FR"/>
    <gs:LocationPreferences>
        <gs:GeoID Value="84"/>
    </gs:LocationPreferences>
</gs:GlobalizationServices>
"@
} else {
    $langXmlContent = @"
<gs:GlobalizationServices xmlns:gs="urn:longhornGlobalizationUnattend">
    <gs:UserList>
        <gs:User UserID="Current" CopySettingsToDefaultUserAcct="true" CopySettingsToSystemAcct="true"/>
    </gs:UserList>
    <gs:UserLocale>
        <gs:Locale Name="en-US" SetAsCurrent="true"/>
    </gs:UserLocale>
    <gs:InputPreferences>
        <gs:InputLanguageID Action="add" ID="0409:00000409" Default="true"/>
        <gs:InputLanguageID Action="add" ID="040c:0000040c"/>
    </gs:InputPreferences>
    <gs:MUILanguagePreferences>
        <gs:MUILanguage Value="en-US"/>
    </gs:MUILanguagePreferences>
    <gs:SystemLocale Name="en-US"/>
    <gs:LocationPreferences>
        <gs:GeoID Value="244"/>
    </gs:LocationPreferences>
</gs:GlobalizationServices>
"@
}

$langXmlContent | Out-File -FilePath $langXmlPath -Encoding UTF8 -Force

Write-Step "Language configuration completed: $Language" "SUCCESS"
Write-Step "Primary keyboard: $(if ($Language -eq 'FR') { 'AZERTY (French)' } else { 'QWERTY (US)' })" "INFO"
Write-Step "Secondary keyboard: $(if ($Language -eq 'FR') { 'QWERTY (US)' } else { 'AZERTY (French)' })" "INFO"
