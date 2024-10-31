# A PowerShell script to provide an easy method for installing HiveMQ on Windows OS.
#
# Instructions for running this PowerShell installation script.
#
# 1) Open Windows PowerShell as administrator.
#
# 2) Temporarily sets the current PowerShell session execution policy to Bypass.
# Set-ExecutionPolicy Bypass -Scope Process -Force
#
# 3) Navigate to the folder where you downloaded the PowerShell script and execute the "Install-HiveMQ-WindowsServer-Standalone.ps1" script to install HiveMQ.
# .\Install-HiveMQ-WindowsServer-Standalone.ps1
#
#

# Accepts HiveMQ version and installation folder as input from the command line, with default values
param (
    # Default HiveMQ version if not provided
    [string]$hivemqVersion = "4.34.0",
    # Default HiveMQ installation folder if not provided
    [string]$installationFolder = "C:\hivemq"
)

# Windows Environment Variables
$tempPath = $env:TEMP

# Set security protocols for downloading files over HTTPS
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072

# Create a new WebClient object to download files from a specified URLs to a local file
$webClient = New-Object System.Net.WebClient

# Write configuration files which by default writes UTF-8 without a BOM
$utf8NoBom = New-Object System.Text.UTF8Encoding $False

# Set Java version to be downloaded and installed
if ($hivemqVersion -ge "4.28.0") {
    $jdkVersion = "21.0.4+7"
} else {
    $jdkVersion = "11.0.24+8"
}

# Define download links
$links = @{
    OpenJDK_Link = "https://api.adoptium.net/v3/installer/version/jdk-$jdkVersion/windows/x64/jre/hotspot/normal/eclipse?project=jdk"
    HiveMQ_Link = "https://releases.hivemq.com/hivemq-$hivemqVersion.zip"
    NSSM_Link = "https://nssm.cc/ci/nssm-2.24-101-g897c7ad.zip"
    MQTTCLI_Link = "https://github.com/hivemq/mqtt-cli/releases/download/v$hivemqVersion/mqtt-cli-$hivemqVersion-win.zip"
}

# Log everything from the PowerShell script session to a file
$hostname = hostname
$datetime = Get-Date -f 'yyyyMMddHHmmss'
Start-Transcript -Path "$installationFolder\deploy\standalone-install-${hostname}-${datetime}.log" | Out-Null
Write-Host "Starting HiveMQ Broker installation." -BackgroundColor Yellow -ForegroundColor Black

# Test download links
Write-Host "1) Testing download links availability..."
function Test-LinkAvailability {
    param (
        [string]$url,
        [string]$linkName
    )
    try {
        $webClient.Headers["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.36"
        $data = $webClient.DownloadData($url)
        if ($data.Length -gt 0) {
            Write-Host "$linkName is reachable and returns data!" -ForegroundColor Green
        } else {
            Write-Host "$linkName might be reachable but returned no data!" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "$linkName is not reachable." -ForegroundColor Red
        throw
    } finally {
        $webClient.Dispose()
    }
}
foreach ($link in $links.GetEnumerator()) {
    Test-LinkAvailability -url $link.Value -linkName $link.Key
}
Write-Host "Testing of all download links was successful!" -ForegroundColor Green

# Install Eclipse Temurin OpenJDK JRE
Write-Host "2) Installing Eclipse Temurin OpenJDK JRE $jdkVersion..."
try {
    $downloadPath = "$tempPath\OpenJDK-jre_x64_windows_hotspot_$jdkVersion.msi" -replace '\+', '_'
    $webClient.DownloadFile($links.OpenJDK_Link, $downloadPath)
    if (-Not (Test-Path $downloadPath)) {
        throw "Eclipse Temurin OpenJDK JRE $jdkVersion download failed."
    }
    Write-Host "Eclipse Temurin OpenJDK JRE $jdkVersion download was successful!" -ForegroundColor Green
    $installDir = "C:\\Program Files\\Eclipse Adoptium\\jre-$jdkVersion-hotspot\\" -replace '\+', '.'
    $arguments = @(
        "/i",
        "`"$downloadPath`"",
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
    if (Test-Path $downloadPath ) {
        Remove-Item -Path $downloadPath -Force
    }
    $webClient.Dispose()
}

# Install HiveMQ
Write-Host "3) Installing HiveMQ $hivemqVersion..."
try {
    $downloadPath = "$tempPath\hivemq-$hivemqVersion.zip"
    $webClient.DownloadFile($links.HiveMQ_Link, $downloadPath)
    if (Test-Path $downloadPath) {
        Write-Host "HiveMQ $hivemqVersion download was successful!" -ForegroundColor Green
    } else {
        throw "HiveMQ $hivemqVersion download failed."
    }
    $extractedFolder = "$tempPath\"
    Expand-Archive -Path $downloadPath -DestinationPath $extractedFolder -Force
    if (Test-Path $extractedFolder) {
        Write-Host "HiveMQ $hivemqVersion extraction was successful!" -ForegroundColor Green
    } else {
        throw "HiveMQ $hivemqVersion extraction failed."
    }
    Copy-Item -Path "$tempPath\hivemq-$hivemqVersion\*" -Destination $installationFolder -Recurse -Force -ErrorAction Stop
    Write-Host "HiveMQ $hivemqVersion installation completed successfully!" -ForegroundColor Green
} catch {
    Write-Host "Failed to install HiveMQ $hivemqVersion." -ForegroundColor Red
    throw
} finally {
    if ((Test-Path $downloadPath) -or (Test-Path "$tempPath\hivemq-$hivemqVersion")) {
        if (Test-Path $downloadPath) {
            Remove-Item -Path $downloadPath -Force
        }
        if (Test-Path "$tempPath\hivemq-$hivemqVersion") {
            Remove-Item -Path "$tempPath\hivemq-$hivemqVersion" -Recurse -Force
        }
    }
    $webClient.Dispose()
}

# Create HiveMQ basic configuration file
Write-Host "4) Creating HiveMQ basic configuration file..."
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
$configFilePath = "$installationFolder\conf\config.xml"
try {
    [System.IO.File]::WriteAllText($configFilePath, $configContent, $utf8NoBom)
    Write-Host "HiveMQ configuration file has been created successfully!" -ForegroundColor Green
} catch {
    Write-Host "Failed to create HiveMQ configuration file." -ForegroundColor Red
    throw
}

# Install HiveMQ MQTT CLI
Write-Host "5) Installing HiveMQ MQTT CLI $hivemqVersion..."
try {
    $downloadPath = "$tempPath\mqtt-cli-$hivemqVersion-win.zip"
    $webClient.DownloadFile($links.MQTTCLI_Link, $downloadPath)
    if (Test-Path $downloadPath) {
        Write-Host "HiveMQ MQTT CLI $hivemqVersion download was successful!" -ForegroundColor Green
    } else {
        throw "HiveMQ MQTT CLI $hivemqVersion download failed."
    }
    $extractedFolder = "$tempPath\mqtt-cli-$hivemqVersion-win"
    Expand-Archive -Path $downloadPath -DestinationPath $extractedFolder -Force
    if (Test-Path $extractedFolder) {
        Write-Host "HiveMQ MQTT CLI $hivemqVersion extraction was successful!" -ForegroundColor Green
    } else {
        throw "HiveMQ MQTT CLI $hivemqVersion extraction failed."
    }
    $destinationPath = "$installationFolder\tools\mqtt-cli\win"
    New-Item -Path $destinationPath -ItemType Directory -Force | Out-Null -ErrorAction Stop
    Copy-Item -Path "$extractedFolder\*" -Destination $destinationPath -Recurse -Force -ErrorAction Stop
    Write-Host "HiveMQ MQTT CLI $hivemqVersion installation completed successfully!" -ForegroundColor Green
} catch {
    Write-Host "Failed to install HiveMQ MQTT CLI $hivemqVersion." -ForegroundColor Red
    throw
} finally {
    if ((Test-Path $downloadPath) -or (Test-Path "$tempPath\mqtt-cli-$hivemqVersion-win")) {
        if (Test-Path $downloadPath) {
            Remove-Item -Path $downloadPath -Force
        }
        if (Test-Path "$tempPath\mqtt-cli-$hivemqVersion-win") {
            Remove-Item -Path "$tempPath\mqtt-cli-$hivemqVersion-win" -Recurse -Force
        }
    }
    $webClient.Dispose()
}

# Open required ports in Windows Defender Firewall
Write-Host "6) Opening required ports in Windows Defender Firewall..."
$rules = @(
    @{
        DisplayName = "HiveMQ MQTT Port 1883"
        Description = "This rule allows inbound TCP connections on port 1883 for HiveMQ Broker. Port 1883 is used for non-TLS MQTT communication. The rule is applicable across Public and Private profiles to support both internal and external MQTT client connections."
        Direction = "Inbound"
        Protocol = "TCP"
        LocalPort = 1883
        Action = "Allow"
        Profile = "Domain, Private, Public"
    },
    @{
        DisplayName = "HiveMQ Control Center Port 8080"
        Description = "This rule allows inbound TCP connections on port 8080 for HiveMQ Control Center. Port 8080 is used for plain HTTP communication. The rule is applicable across Public and Private profiles to support both internal and external HTTP connections."
        Direction = "Inbound"
        Protocol = "TCP"
        LocalPort = 8080
        Action = "Allow"
        Profile = "Domain, Private, Public"
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

# Check if ports 1883 and 8080 are open and listening
Write-Host "7) Checking if ports 1883 and 8080 are open and listening for connections..."
$ports = @(
    @{
        Port = 1883
    },
    @{
        Port = 8080
    }
)
function Test-Port {
    param (
        [int]$Port
    )

    try {
        $listener = New-Object System.Net.Sockets.TcpListener '0.0.0.0', $Port
        $listener.Start()
        $listener.Stop()
        return $true
    } catch {
        return $false
    }
}
foreach ($port in $ports) {
    $result = Test-Port -Port $port.Port
    if ($result) {
        Write-Host "Port $($port.Port) is open and listening." -ForegroundColor Green
    } else {
        Write-Host "Port $($port.Port) may be blocked or in use by another service." -ForegroundColor Red
    }
}

# Set JVM Heap Size
Write-Host "8) Configuring JVM Heap Size with 50% of the RAM available on the system..."
$filePath = "$installationFolder\bin\run.bat"
try {
    $fileContent = Get-Content $filePath -ErrorAction Stop
    # Check if HiveMQ version is greater than or equal to 4.28.0 due to changes in HiveMQ Start Script for Windows
    if ($hivemqVersion -ge "4.28.0") {
        $searchLine = 'set "JAVA_OPTS=%JAVA_OPTS% -Djava.net.preferIPv4Stack=true"'
        $addLine = 'set "JAVA_OPTS=%JAVA_OPTS% -XX:+UnlockExperimentalVMOptions -XX:InitialRAMPercentage=40 -XX:MaxRAMPercentage=50 -XX:MinRAMPercentage=30"'
    } else {
        $searchLine = 'set "JAVA_OPTS=-Djava.net.preferIPv4Stack=true -noverify %JAVA_OPTS%"'
        $addLine = '  set "JAVA_OPTS=%JAVA_OPTS% -XX:+UnlockExperimentalVMOptions -XX:InitialRAMPercentage=40 -XX:MaxRAMPercentage=50 -XX:MinRAMPercentage=30"'
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
        Write-Host "The search line was not found in the file." -ForegroundColor Red
    }
} catch {
    Write-Host "Failed to configure JVM Heap Size in the file: $filePath." -ForegroundColor Red
    throw
}

# Create and start HiveMQ service
Write-Host "9) Creating HiveMQ service..."
try {
    $downloadPath = "$tempPath\nssm-2.24-101-g897c7ad.zip"
    $webClient.DownloadFile($links.NSSM_Link, $downloadPath)
    if (Test-Path $downloadPath) {
        Write-Host "NSSM download was successful!" -ForegroundColor Green
    } else {
        Write-Host "NSSM download failed." -ForegroundColor Red
    }
    $extractedFolder = "$tempPath\"
    Expand-Archive -Path $downloadPath -DestinationPath $extractedFolder -Force
    if (Test-Path $extractedFolder) {
        Write-Host "NSSM extraction was successful!" -ForegroundColor Green
    } else {
        Write-Host "NSSM extraction failed." -ForegroundColor Red
    }

    if (-Not (Test-Path -Path "$installationFolder\windows-service")) {
        New-Item -Path "$installationFolder\windows-service" -ItemType Directory | Out-Null -ErrorAction Stop
        Write-Host "Directory '$installationFolder\windows-service' created!" -ForegroundColor Green
    } else {
        Write-Host "Directory '$installationFolder\windows-service' already exists, skipping creation..." -ForegroundColor Yellow
    }

    $nssmPath = "$installationFolder\windows-service\nssm.exe"
    Copy-Item -Path "$tempPath\nssm-2.24-101-g897c7ad\win64\nssm.exe" -Destination $nssmPath -Force -ErrorAction Stop

    $serviceCommands = @(
        @{Arguments = "install HiveMQService $installationFolder\bin\run.bat"; Description = "Installing HiveMQ service..."},
        @{Arguments = "set HiveMQService Application $installationFolder\bin\run.bat"; Description = "Setting service Application Path..."},
        @{Arguments = "set HiveMQService AppDirectory $installationFolder\bin"; Description = "Setting service App Directory..."},
        @{Arguments = "set HiveMQService DisplayName HiveMQ Service"; Description = "Setting service Display Name..."},
        @{Arguments = "set HiveMQService Description HiveMQ Enterprise MQTT Broker"; Description = "Setting service Description..."},
        @{Arguments = "set HiveMQService ObjectName LocalSystem"; Description = "Setting User Account under which the service runs..."},
        @{Arguments = "set HiveMQService Type SERVICE_WIN32_OWN_PROCESS"; Description = "Setting service Type..."},
        @{Arguments = "set HiveMQService DependOnService RpcSS LanmanWorkstation"; Description = "Setting Network Services which must start before the service can start..."},
        @{Arguments = "set HiveMQService AppExit Default Restart"; Description = "Setting service App Exit Policy..."},
        @{Arguments = "set HiveMQService Start SERVICE_AUTO_START"; Description = "Setting service Startup Type..."}
    )
    foreach ($cmd in $serviceCommands) {
        Start-Process -FilePath $nssmPath -ArgumentList $cmd.Arguments -Wait -ErrorAction Stop *> $null
        Write-Host "$($cmd.Description)" -ForegroundColor Cyan
    }
    Write-Host "10) Starting HiveMQ service..."
    Start-Sleep -Seconds 5
    Start-Process -FilePath $nssmPath -ArgumentList 'start', 'HiveMQService' | Out-Null
    While ($true) {
        $status = (Get-Service -Name HiveMQService).Status
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
    if ((Test-Path $downloadPath) -or (Test-Path "$tempPath\nssm-2.24-101-g897c7ad")) {
        if (Test-Path $downloadPath) {
            Remove-Item -Path $downloadPath -Force
        }
        if (Test-Path "$tempPath\nssm-2.24-101-g897c7ad") {
            Remove-Item -Path "$tempPath\nssm-2.24-101-g897c7ad" -Recurse -Force
        }
    }
    $webClient.Dispose()
}

Write-Host "The HiveMQ MQTT Broker has been installed and operating correctly!" -BackgroundColor Yellow -ForegroundColor Black
Write-Host " "
Write-Host "Next Steps:" -BackgroundColor Yellow -ForegroundColor Black
Write-Host "1. Open your browser and go to: http://localhost:8080" -BackgroundColor Yellow -ForegroundColor Black
Write-Host "2. If you see the HiveMQ Control Center login screen, HiveMQ is running correctly." -BackgroundColor Yellow -ForegroundColor Black
Stop-Transcript | Out-Null
