# A PowerShell script to uninstall HiveMQ and related components installed by the HiveMQ PowerShell installation script.
#
# Instructions for running this PowerShell uninstallation script:
#
# 1) Open Windows PowerShell as administrator.
#
# 2) Temporarily set the current PowerShell session execution policy to Bypass:
# Set-ExecutionPolicy Bypass -Scope Process -Force
#
# 3) Navigate to the folder where you saved this PowerShell script and execute it:
# .\Uninstall-HiveMQ-WindowsServer-Standalone.ps1
#

# Accepts HiveMQ installation folder as input from the command line, with default value
param (
    # Default HiveMQ installation folder if not provided
    [string]$installationFolder = "C:\hivemq"
)

Write-Host "Starting HiveMQ Broker uninstallation." -BackgroundColor Yellow -ForegroundColor Black

# Stop and remove the HiveMQ service
Write-Host "1) Stopping and removing the HiveMQ service..."
try {
    $nssmPath = "$installationFolder\windows-service\nssm.exe"
    if (Test-Path $nssmPath) {
        # Stop the service
        Start-Process -FilePath $nssmPath -ArgumentList 'stop', 'HiveMQService', 'confirm' -Wait -ErrorAction Stop | Out-Null
        Write-Host "HiveMQ service has been stopped successfully!" -ForegroundColor Green

        # Remove the service
        Start-Process -FilePath $nssmPath -ArgumentList 'remove', 'HiveMQService', 'confirm' -Wait -ErrorAction Stop | Out-Null
        Write-Host "HiveMQ service has been removed successfully!" -ForegroundColor Green
    } else {
        Write-Host "NSSM executable not found at $nssmPath. Cannot stop and remove HiveMQ service." -ForegroundColor Red
    }
} catch {
    Write-Host "Failed to stop and remove HiveMQ service." -ForegroundColor Red
    throw
}

# Rename the HiveMQ installation directory
Write-Host "2) Renaming the HiveMQ installation directory..."
try {
    if (Test-Path $installationFolder) {
        $datetime = Get-Date -Format 'yyyyMMdd_HHmmss'
        $backupFolder = "${installationFolder}_uninstall_backup_$datetime"
        Rename-Item -Path $installationFolder -NewName $backupFolder -Force
        Write-Host "HiveMQ installation directory has been renamed successfully!" -ForegroundColor Green
    } else {
        Write-Host "HiveMQ installation directory does not exist. Skipping..." -ForegroundColor Yellow
    }
} catch {
    Write-Host "Failed to rename HiveMQ installation directory." -ForegroundColor Red
    throw
}

# Uninstall Eclipse Temurin OpenJDK JRE based on major Java versions
Write-Host "3) Uninstalling Eclipse Temurin OpenJDK JRE..."
try {
    # Define the major Java versions to uninstall
    $javaVersions = @("11", "21")

    $uninstalled = $false
    foreach ($version in $javaVersions) {
        # Retrieve installed products matching the JRE name pattern for the major version
        $apps = Get-WmiObject -Class Win32_Product -Filter "Name LIKE 'Eclipse Temurin JRE with Hotspot ${version}%%(x64)'" -ErrorAction SilentlyContinue

        if ($apps) {
            foreach ($app in $apps) {
                $app.Uninstall() | Out-Null
                Write-Host "Uninstalled $($app.Name) successfully!" -ForegroundColor Green
                $uninstalled = $true
            }
        }
    }
    if (-not $uninstalled) {
        Write-Host "Eclipse Temurin OpenJDK JRE not found for Java 11 and 21 versions. Skipping..." -ForegroundColor Yellow
    }
} catch {
    Write-Host "Failed to uninstall Eclipse Temurin OpenJDK JRE." -ForegroundColor Red
    throw
}

# Remove firewall rules
Write-Host "4) Removing Windows Defender Firewall rules..."
$rules = @(
    "HiveMQ MQTT Port 1883",
    "HiveMQ Control Center Port 8080"
)
foreach ($ruleName in $rules) {
    try {
        if (Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue) {
            Remove-NetFirewallRule -DisplayName $ruleName -ErrorAction Stop
            Write-Host "Firewall rule '$ruleName' has been removed successfully!" -ForegroundColor Green
        } else {
            Write-Host "Firewall rule '$ruleName' does not exist. Skipping..." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "Failed to remove firewall rule '$ruleName'." -ForegroundColor Red
        throw
    }
}

# Remove temporary files if any
Write-Host "5) Cleaning up temporary files..."
$tempPath = $env:TEMP
$tempFiles = @(
    "$tempPath\OpenJDK-jre_x64_windows_hotspot_*",
    "$tempPath\hivemq-*.zip",
    "$tempPath\hivemq-*",
    "$tempPath\mqtt-cli-*-win.zip",
    "$tempPath\mqtt-cli-*-win",
    "$tempPath\nssm-*-g*.zip",
    "$tempPath\nssm-*-g*"
)
foreach ($tempFile in $tempFiles) {
    try {
        Get-ChildItem -Path $tempFile -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    } catch {
        # Ignore errors
    }
}
Write-Host "Temporary files have been cleaned up." -ForegroundColor Green
Write-Host "HiveMQ and all related components have been uninstalled successfully!" -BackgroundColor Yellow -ForegroundColor Black
if ($backupFolder) {
    Write-Host "The HiveMQ installation directory was renamed to '$backupFolder'." -BackgroundColor Yellow -ForegroundColor Black
}
