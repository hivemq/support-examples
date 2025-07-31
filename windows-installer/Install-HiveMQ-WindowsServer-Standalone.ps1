# A PowerShell script to provide an easy method for installing HiveMQ on Windows OS.
#
# Instructions for running this PowerShell HiveMQ installation script.
#
# 1) Open Windows PowerShell as administrator.
#
# 2) Temporarily sets the current PowerShell session execution policy to Bypass.
#    Set-ExecutionPolicy Bypass -Scope Process -Force
#
# 3) Navigate to the folder where you downloaded the .ps1 script and execute it.
#    .\Install-HiveMQ-WindowsServer-Standalone.ps1
#
# If the Windows Server lacks outbound internet access, or if the required download
# domains are blocked by a company network policy, this script will automatically
# fall back to using local offline installation files located in the same directory.
#
#

# Accepts HiveMQ version and installation folder as input from the command line, with default values
param (
    # Default HiveMQ version if not provided
    [string]$hivemqVersion = "4.42.0",
    # Default HiveMQ installation folder if not provided
    [string]$installationFolder = 'C:\hivemq'
)

# Track the script directory for offline fallback
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Windows Environment Variables
$tempPath = $env:TEMP

# Set security protocols for downloading files over HTTPS
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072

# Decide Java version to be downloaded and installed based on HiveMQ version
if ($hivemqVersion -ge "4.28.0") {
    $jdkVersion = "21.0.7+6"
} else {
    $jdkVersion = "11.0.27+6"
}

# Offline file names (adjust if your locally saved filenames differ)
$offlineOpenJDK  = "OpenJDK-jre_x64_windows_hotspot_$($jdkVersion -replace '\\+', '_').msi"
$offlineHiveMQZip = "hivemq-$hivemqVersion.zip"
$offlineHiveMQSha = "hivemq-$hivemqVersion.zip.sha256"
$offlineMqttCli   = "mqtt-cli-$hivemqVersion-win.zip"
$offlineNssmZip   = "nssm-2.24-101-g897c7ad.zip"

# Define fallbackMap
$fallbackMap = @{
    'OpenJDK_Link'    = $offlineOpenJDK
    'HiveMQ_Link'     = $offlineHiveMQZip
    'HiveMQ_SHA_Link' = $offlineHiveMQSha
    'MQTTCLI_Link'    = $offlineMqttCli
    'NSSM_Link'       = $offlineNssmZip
}

# User-friendly link names
$friendlyNames = @{
    'OpenJDK_Link'    = 'OpenJDK download link'
    'HiveMQ_Link'     = 'HiveMQ download link'
    'HiveMQ_SHA_Link' = 'HiveMQ SHA Checksum download link'
    'MQTTCLI_Link'    = 'HiveMQ MQTT CLI download link'
    'NSSM_Link'       = 'NSSM download link'
}

# Define download links
$links = @{
    OpenJDK_Link    = "https://api.adoptium.net/v3/installer/version/jdk-$jdkVersion/windows/x64/jre/hotspot/normal/eclipse?project=jdk"
    HiveMQ_Link     = "https://releases.hivemq.com/hivemq-$hivemqVersion.zip"
    HiveMQ_SHA_Link = "https://releases.hivemq.com/hivemq-$hivemqVersion.zip.sha256"
    MQTTCLI_Link    = "https://github.com/hivemq/mqtt-cli/releases/download/v$hivemqVersion/mqtt-cli-$hivemqVersion-win.zip"
    NSSM_Link       = "https://nssm.cc/ci/nssm-2.24-101-g897c7ad.zip"
}

# Per-link availability hashtable
$linkAvailability = @{
    'OpenJDK_Link'    = $true
    'HiveMQ_Link'     = $true
    'HiveMQ_SHA_Link' = $true
    'MQTTCLI_Link'    = $true
    'NSSM_Link'       = $true
}

# Log everything from the PowerShell script session to a file
$hostname = hostname
$datetime = Get-Date -f 'yyyyMMddHHmmss'
if (-not (Test-Path "$installationFolder\\deploy")) {
    New-Item -ItemType Directory -Path "$installationFolder\\deploy" -Force | Out-Null
}
Start-Transcript -Path "$installationFolder\\deploy\\standalone-install-${hostname}-${datetime}.log" | Out-Null
Write-Host " "
Write-Host "-----------------------------------------------------------------------------------"
Write-Host "Starting HiveMQ Broker installation..." -BackgroundColor Green -ForegroundColor Black
Write-Host "-----------------------------------------------------------------------------------"
Write-Host " "

# -------------------------------------------------------------------------
# STEP 1) Test link availability
# -------------------------------------------------------------------------
Write-Host "1) Testing download links availability (will offline fallback if unreachable)..." -BackgroundColor Yellow -ForegroundColor Black

function Test-LinkAvailability {
    param (
        [string]$url,
        [string]$linkName
    )
    # Create a new WebClient object to download files from a specified URLs to a local file
    $wc = New-Object System.Net.WebClient
    $wc.Headers["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.36"
    try {
        $data = $wc.DownloadData($url)
        if ($data.Length -gt 0) {
            Write-Host "$($friendlyNames[$linkName]) is reachable and returns data!" -ForegroundColor Green
        } else {
            Write-Host "$($friendlyNames[$linkName]) returned no data!" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "$($friendlyNames[$linkName]) is not reachable (will attempt local/offline files if needed)." -ForegroundColor Red

        $fallbackFilename = $fallbackMap[$linkName]
        $localPath = Join-Path $scriptDir $fallbackFilename
        
        if (-not (Test-Path $localPath)) {
            Write-Host "Please manually download the file from: $url"
            Write-Host "And place the file '$fallbackFilename' in the same folder as this script to enable offline installation."
        }
        else {
            Write-Host "File '$fallbackFilename' found in the same folder as this script. Offline installation is possible." -ForegroundColor Green
        }
        
        # Mark link as unreachable
        $linkAvailability[$linkName] = $false
    }
    finally {
        $wc.Dispose()
    }
}

foreach ($link in $links.GetEnumerator()) {
    Test-LinkAvailability -url $link.Value -linkName $link.Key
}

if ($linkAvailability.Values -notcontains $false) {
    Write-Host "Testing of all download links was successful!" -ForegroundColor Green
} else {
    Write-Host "At least one link is not reachable; will attempt local/offline files where needed." -ForegroundColor Cyan
}

# Helper function tries online download, else offline fallback
function Try-DownloadOrFallback {
    param(
        [string]$remoteUrl,
        [string]$fallbackFilename,
        [string]$targetDownloadPath,
        [string]$linkName
    )

    if (-not $linkAvailability[$linkName]) {
        Write-Host "Skipping online download for $fallbackFilename. Trying offline installation..."
        $localPath = Join-Path $scriptDir $fallbackFilename
        if (-not (Test-Path $localPath)) {
            throw "File not found: $localPath"
        }
        Copy-Item $localPath $targetDownloadPath -Force
        Write-Host "Local copy succeeded: $targetDownloadPath"
        return
    }

    $wc = New-Object System.Net.WebClient
    Write-Host "Attempting to download $remoteUrl ..."
    try {
        $wc.DownloadFile($remoteUrl, $targetDownloadPath)
        if (-not (Test-Path $targetDownloadPath)) {
            throw "DownloadFile reported success but file not found: $targetDownloadPath"
        }
        Write-Host "Download succeeded: $targetDownloadPath"
    } catch {
        Write-Host "Download failed, attempting fallback local/offline copy..."
        $localPath = Join-Path $scriptDir $fallbackFilename
        if (-not (Test-Path $localPath)) {
            throw "File not found: $localPath"
        }
        Copy-Item $localPath $targetDownloadPath -Force
        Write-Host "Local copy succeeded: $targetDownloadPath"
    } finally {
        $wc.Dispose()
    }
}

# -------------------------------------------------------------------------
# STEP 2) Install Eclipse Temurin OpenJDK JRE
# -------------------------------------------------------------------------
Write-Host "2) Installing Eclipse Temurin OpenJDK JRE $jdkVersion..." -BackgroundColor Yellow -ForegroundColor Black
$openJdkMsiPath = "$tempPath\\OpenJDK-jre_x64_windows_hotspot_$($jdkVersion -replace '\+', '_').msi"
try {
    Try-DownloadOrFallback `
        -remoteUrl $links.OpenJDK_Link `
        -fallbackFilename $offlineOpenJDK `
        -targetDownloadPath $openJdkMsiPath `
        -linkName 'OpenJDK_Link'

    $installDir = "C:\\Program Files\\Eclipse Adoptium\\jre-$jdkVersion-hotspot\\" -replace '\+', '.'
    $arguments = @(
        "/i",
        "`"$openJdkMsiPath`"",
        "ADDLOCAL=FeatureMain,FeatureEnvironment,FeatureJarFileRunWith,FeatureJavaHome",
        "INSTALLDIR=`"$installDir`"",
        "/quiet"
    )
    $OpenJDKinstallProcess = Start-Process -FilePath "msiexec" -ArgumentList $arguments -Wait -Verb RunAs -PassThru
    if ($OpenJDKinstallProcess.ExitCode -ne 0) {
        throw "Installation failed with exit code: $($OpenJDKinstallProcess.ExitCode)"
    }
    Write-Host "Eclipse Temurin OpenJDK JRE $jdkVersion installation completed successfully!" -ForegroundColor Green
} catch {
    Write-Host "Eclipse Temurin OpenJDK JRE $jdkVersion installation failed." -ForegroundColor Red
    throw
} finally {
    if (Test-Path $openJdkMsiPath) {
        Remove-Item -Path $openJdkMsiPath -Force
    }
}

# -------------------------------------------------------------------------
# STEP 3) Install HiveMQ
# -------------------------------------------------------------------------
Write-Host "3) Installing HiveMQ $hivemqVersion..." -BackgroundColor Yellow -ForegroundColor Black
try {
    $hiveMQShaLocal = "$tempPath\\hivemq-$hivemqVersion.zip.sha256"
    Try-DownloadOrFallback `
        -remoteUrl $links.HiveMQ_SHA_Link `
        -fallbackFilename $offlineHiveMQSha `
        -targetDownloadPath $hiveMQShaLocal `
        -linkName 'HiveMQ_SHA_Link'

    $hiveMQZipLocal = "$tempPath\\hivemq-$hivemqVersion.zip"
    Try-DownloadOrFallback `
        -remoteUrl $links.HiveMQ_Link `
        -fallbackFilename $offlineHiveMQZip `
        -targetDownloadPath $hiveMQZipLocal `
        -linkName 'HiveMQ_Link'

    # Verify checksum
    if ((Test-Path $hiveMQShaLocal) -and (Test-Path $hiveMQZipLocal)) {
        $sourceChecksum    = Get-Content -Path $hiveMQShaLocal -Raw
        $generatedChecksum = @(certutil -hashfile $hiveMQZipLocal SHA256)
        if ($sourceChecksum -eq $generatedChecksum[1]) {
            Write-Host "Checksum validation was successful!" -ForegroundColor Green
        } else {
            throw "Checksum validation failed. Expected: $sourceChecksum Actual: $($generatedChecksum[1])"
        }
    } else {
        throw "HiveMQ or its SHA file is missing."
    }

    Expand-Archive -Path $hiveMQZipLocal -DestinationPath $tempPath -Force
    if (Test-Path "$tempPath\\hivemq-$hivemqVersion") {
        Write-Host "HiveMQ $hivemqVersion extraction was successful!" -ForegroundColor Green
    } else {
        throw "HiveMQ $hivemqVersion extraction failed."
    }
    Copy-Item -Path "$tempPath\\hivemq-$hivemqVersion\\*" -Destination $installationFolder -Recurse -Force -ErrorAction Stop
    Write-Host "HiveMQ $hivemqVersion installation completed successfully!" -ForegroundColor Green
} catch {
    Write-Host "Failed to install HiveMQ $hivemqVersion." -ForegroundColor Red
    throw
} finally {
    if (Test-Path "$tempPath\\hivemq-$hivemqVersion") {
        Remove-Item -Path "$tempPath\\hivemq-$hivemqVersion" -Recurse -Force
    }
    if (Test-Path $hiveMQZipLocal) {
        Remove-Item -Path $hiveMQZipLocal -Force
    }
    if (Test-Path $hiveMQShaLocal) {
        Remove-Item -Path $hiveMQShaLocal -Force
    }
}

# -------------------------------------------------------------------------
# STEP 4) Create HiveMQ basic configuration file
# -------------------------------------------------------------------------
Write-Host "4) Creating HiveMQ basic configuration file..." -BackgroundColor Yellow -ForegroundColor Black
$configFilePath = "$installationFolder\\conf\\config.xml"
$configContent = @"
<?xml version="1.0" encoding="UTF-8" ?>
<hivemq xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xsi:noNamespaceSchemaLocation="config.xsd">

    <listeners>
        <!-- TCP listener configuration -->
        <tcp-listener>
            <port>1883</port>
            <bind-address>0.0.0.0</bind-address>
        </tcp-listener>
    </listeners>
    <!-- Control Center HTTP listener configuration -->
    <control-center>
        <enabled>true</enabled>
        <listeners>
            <http>
                <port>8080</port>
                <bind-address>0.0.0.0</bind-address>
            </http>
        </listeners>
    </control-center>
    <anonymous-usage-statistics>
        <enabled>true</enabled>
    </anonymous-usage-statistics>
</hivemq>
"@
try {
    # Write configuration files which by default writes UTF-8 without a BOM
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($configFilePath, $configContent, $utf8NoBom)
    Write-Host "HiveMQ configuration file has been created successfully!" -ForegroundColor Green
} catch {
    Write-Host "Failed to create HiveMQ configuration file." -ForegroundColor Red
    throw
}

# -------------------------------------------------------------------------
# STEP 5) Install HiveMQ MQTT CLI
# -------------------------------------------------------------------------
Write-Host "5) Installing HiveMQ MQTT CLI $hivemqVersion..." -BackgroundColor Yellow -ForegroundColor Black
try {
    $mqttCliZipLocal = "$tempPath\\mqtt-cli-$hivemqVersion-win.zip"
    Try-DownloadOrFallback `
        -remoteUrl $links.MQTTCLI_Link `
        -fallbackFilename $offlineMqttCli `
        -targetDownloadPath $mqttCliZipLocal `
        -linkName 'MQTTCLI_Link'

    $extractedFolder = "$tempPath\\mqtt-cli-$hivemqVersion-win"
    Expand-Archive -Path $mqttCliZipLocal -DestinationPath $extractedFolder -Force
    if (Test-Path $extractedFolder) {
        Write-Host "HiveMQ MQTT CLI $hivemqVersion extraction was successful!" -ForegroundColor Green
    } else {
        throw "HiveMQ MQTT CLI $hivemqVersion extraction failed."
    }
    $destinationPath = "$installationFolder\\tools\\mqtt-cli\\win"
    if (-not (Test-Path $destinationPath)) {
        New-Item -Path $destinationPath -ItemType Directory -Force | Out-Null -ErrorAction Stop
    }
    Copy-Item -Path "$extractedFolder\\*" -Destination $destinationPath -Recurse -Force -ErrorAction Stop
    Write-Host "HiveMQ MQTT CLI $hivemqVersion installation completed successfully!" -ForegroundColor Green
} catch {
    Write-Host "Failed to install HiveMQ MQTT CLI $hivemqVersion." -ForegroundColor Red
    throw
} finally {
    if (Test-Path $extractedFolder) {
        Remove-Item -Path $extractedFolder -Recurse -Force
    }
    if (Test-Path $mqttCliZipLocal) {
        Remove-Item -Path $mqttCliZipLocal -Force
    }
}

# -------------------------------------------------------------------------
# STEP 6) Open required ports in Windows Defender Firewall
# -------------------------------------------------------------------------
Write-Host "6) Opening required ports in Windows Defender Firewall..." -BackgroundColor Yellow -ForegroundColor Black
$rules = @(
    @{
        DisplayName = "HiveMQ MQTT Port 1883"
        Description = "This rule allows inbound TCP connections on port 1883 for HiveMQ Broker. Port 1883 is used for non-TLS MQTT communication. The rule is applicable across Public and Private profiles to support both internal and external MQTT client connections."
        Direction   = "Inbound"
        Protocol    = "TCP"
        LocalPort   = 1883
        Action      = "Allow"
        Profile     = "Domain, Private, Public"
    },
    @{
        DisplayName = "HiveMQ Control Center Port 8080"
        Description = "This rule allows inbound TCP connections on port 8080 for HiveMQ Control Center. Port 8080 is used for plain HTTP communication. The rule is applicable across Public and Private profiles to support both internal and external HTTP connections."
        Direction   = "Inbound"
        Protocol    = "TCP"
        LocalPort   = 8080
        Action      = "Allow"
        Profile     = "Domain, Private, Public"
    }
)
foreach ($rule in $rules) {
    try {
        if (Get-NetFirewallRule -DisplayName $rule.DisplayName -ErrorAction SilentlyContinue) {
            Write-Host "The firewall rule '$($rule.DisplayName)' already exists." -ForegroundColor Cyan
        } else {
            New-NetFirewallRule @rule | Out-Null -ErrorAction Stop
            Write-Host "The firewall rule '$($rule.DisplayName)' has been created successfully!" -ForegroundColor Green
        }
    } catch {
        Write-Host "Failed to create Windows Defender Firewall rule '$($rule.DisplayName)'." -ForegroundColor Red
        throw
    }
}

# -------------------------------------------------------------------------
# STEP 7) Check if ports 1883, 8080 are open
# -------------------------------------------------------------------------
Write-Host "7) Checking if ports 1883 and 8080 are open and listening for connections..." -BackgroundColor Yellow -ForegroundColor Black
$ports = 1883, 8080
foreach ($p in $ports) {
    try {
        $listener = New-Object System.Net.Sockets.TcpListener '0.0.0.0', $p
        $listener.Start()
        $listener.Stop()
        Write-Host "Port $p is open and listening." -ForegroundColor Green
    } catch {
        Write-Host "Port $p may be blocked or in use by another service." -ForegroundColor Red
    }
}

# -------------------------------------------------------------------------
# STEP 8) Set JVM Heap Size
# -------------------------------------------------------------------------
Write-Host "8) Configuring JVM Heap Size with 50% of the RAM available on the system..." -BackgroundColor Yellow -ForegroundColor Black
$filePath = "$installationFolder\\bin\\run.bat"
try {
    $fileContent = Get-Content $filePath -ErrorAction Stop
    if ($hivemqVersion -ge "4.28.0") {
        $searchLine = 'set "JAVA_OPTS=%JAVA_OPTS% -Djava.net.preferIPv4Stack=true"'
        $addLine    = 'set "JAVA_OPTS=%JAVA_OPTS% -XX:+UnlockExperimentalVMOptions -XX:InitialRAMPercentage=50 -XX:MaxRAMPercentage=50"'
    } else {
        $searchLine = 'set "JAVA_OPTS=-Djava.net.preferIPv4Stack=true -noverify %JAVA_OPTS%"'
        $addLine    = '  set "JAVA_OPTS=%JAVA_OPTS% -XX:+UnlockExperimentalVMOptions -XX:InitialRAMPercentage=50 -XX:MaxRAMPercentage=50"'
    }
    $lineIndex = $null
    for ($i = 0; $i -lt $fileContent.Count; $i++) {
        if ($fileContent[$i] -match $searchLine) {
            $lineIndex = $i + 1
            break
        }
    }
    if ($null -ne $lineIndex) {
        $fileContent = $fileContent[0..($lineIndex-1)] + $addLine + $fileContent[$lineIndex..($fileContent.Count - 1)]
        $fileContent | Set-Content $filePath -ErrorAction Stop
        Write-Host "JVM Heap Size has been configured successfully!" -ForegroundColor Green
    } else {
        Write-Host "The search line was not found in $filePath." -ForegroundColor Red
    }
} catch {
    Write-Host "Failed to configure JVM Heap Size in $filePath." -ForegroundColor Red
    throw
}

# -------------------------------------------------------------------------
# STEP 9 and 10) Create and start HiveMQ Windows Service (using NSSM)
# -------------------------------------------------------------------------
Write-Host "9) Creating HiveMQ Windows Service (using NSSM)..." -BackgroundColor Yellow -ForegroundColor Black
try {
    $nssmZipLocal = "$tempPath\\nssm-2.24-101-g897c7ad.zip"
    Try-DownloadOrFallback `
        -remoteUrl $links.NSSM_Link `
        -fallbackFilename $offlineNssmZip `
        -targetDownloadPath $nssmZipLocal `
        -linkName 'NSSM_Link'

    $extractedFolder = "$tempPath\\nssm-2.24-101-g897c7ad"
    Expand-Archive -Path $nssmZipLocal -DestinationPath $tempPath -Force
    if (Test-Path $extractedFolder) {
        Write-Host "NSSM extraction was successful!" -ForegroundColor Green
    } else {
        Write-Host "NSSM extraction failed." -ForegroundColor Red
    }

    if (-not (Test-Path "$installationFolder\\windows-service")) {
        New-Item -Path "$installationFolder\\windows-service" -ItemType Directory | Out-Null -ErrorAction Stop
        Write-Host "Directory '$installationFolder\\windows-service' created!" -ForegroundColor Green
    } else {
        Write-Host "Directory '$installationFolder\\windows-service' already exists, skipping creation..." -ForegroundColor Yellow
    }

    $nssmPath = "$installationFolder\\windows-service\\nssm.exe"
    Copy-Item -Path "$extractedFolder\\win64\\nssm.exe" -Destination $nssmPath -Force -ErrorAction Stop

    $serviceCommands = @(
        @{Arguments = "install HiveMQService $installationFolder\\bin\\run.bat"; Description = "Installing HiveMQ Windows Service..."},
        @{Arguments = "set HiveMQService Application $installationFolder\\bin\\run.bat"; Description = "Setting service Application Path..."},
        @{Arguments = "set HiveMQService AppDirectory $installationFolder\\bin"; Description = "Setting service App Directory..."},
        @{Arguments = "set HiveMQService DisplayName HiveMQ Service"; Description = "Setting service Display Name..."},
        @{Arguments = "set HiveMQService Description HiveMQ Enterprise MQTT Broker"; Description = "Setting service Description..."},
        @{Arguments = "set HiveMQService ObjectName LocalSystem"; Description = "Setting service run account..."},
        @{Arguments = "set HiveMQService Type SERVICE_WIN32_OWN_PROCESS"; Description = "Setting service type..."},
        @{Arguments = "set HiveMQService DependOnService RpcSS LanmanWorkstation"; Description = "Setting dependencies..."},
        @{Arguments = "set HiveMQService AppExit Default Restart"; Description = "Setting service App Exit Policy..."},
        @{Arguments = "set HiveMQService Start SERVICE_AUTO_START"; Description = "Setting service Startup Type..."}
    )
    foreach ($cmd in $serviceCommands) {
        Start-Process -FilePath $nssmPath -ArgumentList $cmd.Arguments -Wait -ErrorAction Stop *> $null
        Write-Host "$($cmd.Description)" -ForegroundColor Cyan
    }

    Write-Host "10) Starting HiveMQ Windows Service..." -BackgroundColor Yellow -ForegroundColor Black
    Start-Sleep -Seconds 5
    Start-Process -FilePath $nssmPath -ArgumentList 'start', 'HiveMQService' | Out-Null

    while ($true) {
        $status = (Get-Service -Name HiveMQService -ErrorAction SilentlyContinue).Status
        Write-Host "HiveMQ Service Status: $status" -ForegroundColor Cyan
        Start-Sleep -Seconds 5
        if ($status -eq 'Running') {
            Write-Host "HiveMQ Service has been created and started successfully!" -ForegroundColor Green
            break
        }
    }
} catch {
    Write-Host "Failed to create and start HiveMQ service." -ForegroundColor Red
    throw
} finally {
    if (Test-Path $nssmZipLocal) {
        Remove-Item -Path $nssmZipLocal -Force
    }
    if (Test-Path $extractedFolder) {
        Remove-Item -Path $extractedFolder -Recurse -Force
    }
}

Write-Host " "
Write-Host "-----------------------------------------------------------------------------------"
Write-Host "The HiveMQ MQTT Broker has been installed and is operational!" -BackgroundColor Green -ForegroundColor Black
Write-Host " "
Write-Host "Next Steps:" -BackgroundColor Green -ForegroundColor Black
Write-Host "1. Open your browser and go to: http://localhost:8080" -BackgroundColor Green -ForegroundColor Black
Write-Host "2. If you see the HiveMQ Control Center login screen, HiveMQ is running correctly." -BackgroundColor Green -ForegroundColor Black
Write-Host "-----------------------------------------------------------------------------------"
Write-Host " "
Stop-Transcript | Out-Null
