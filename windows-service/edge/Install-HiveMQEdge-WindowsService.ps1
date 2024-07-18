# A PowerShell script to provide an alternative method for installing the HiveMQ Edge service on Windows OS

# HiveMQ Edge installation folder
$installationFolder = "C:\hivemq"

# Windows Environment Variables
$tempPath = $env:TEMP

# Set security protocols for downloading files over HTTPS
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072

# Create a new WebClient object to download files from a specified URLs to a local file
$webClient = New-Object System.Net.WebClient

# Define NSSM download link
$links = @{
    NSSM_Link = "https://nssm.cc/ci/nssm-2.24-101-g897c7ad.zip"
}

# Test download links
Write-Host "1) Testing NSSM download link availability..."
function Test-LinkAvailability {
    param (
        [string]$url,
        [string]$linkName
    )
    try {
        $webClient.Headers["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.36"
        $data = $webClient.DownloadData($url)
        if ($data.Length -gt 0) {
            Write-Host "NSSM download link is reachable and returns data!" -ForegroundColor Green
        } else {
            Write-Host "NSSM download link might be reachable but returned no data!" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "NSSM download link is not reachable." -ForegroundColor Red
        throw
    } finally {
        $webClient.Dispose()
    }
}
foreach ($link in $links.GetEnumerator()) {
    Test-LinkAvailability -url $link.Value -linkName $link.Key
}
Write-Host "Testing of NSSM download link was successful!" -ForegroundColor Green

# Create and start the HiveMQ Edge service
Write-Host "2) Creating HiveMQ Edge service..."
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
        @{Arguments = "install HiveMQEdgeService $installationFolder\bin\run.bat"; Description = "Installing HiveMQ Edge service..."},
        @{Arguments = "set HiveMQEdgeService Application $installationFolder\bin\run.bat"; Description = "Setting service Application Path..."},
        @{Arguments = "set HiveMQEdgeService AppDirectory $installationFolder\bin"; Description = "Setting service App Directory..."},
        @{Arguments = "set HiveMQEdgeService DisplayName HiveMQ Edge Service"; Description = "Setting service Display Name..."},
        @{Arguments = "set HiveMQEdgeService Description HiveMQ Edge Software-based Edge MQTT Gateway"; Description = "Setting service Description..."},
        @{Arguments = "set HiveMQEdgeService ObjectName LocalSystem"; Description = "Setting User Account under which the service runs..."},
        @{Arguments = "set HiveMQEdgeService Type SERVICE_WIN32_OWN_PROCESS"; Description = "Setting service Type..."},
        @{Arguments = "set HiveMQEdgeService DependOnService RpcSS LanmanWorkstation"; Description = "Setting Network Services which must start before the service can start..."},
        @{Arguments = "set HiveMQEdgeService AppExit Default Restart"; Description = "Setting service App Exit Policy..."},
        @{Arguments = "set HiveMQEdgeService Start SERVICE_AUTO_START"; Description = "Setting service Startup Type..."}
    )
    foreach ($cmd in $serviceCommands) {
        Start-Process -FilePath $nssmPath -ArgumentList $cmd.Arguments -Wait -ErrorAction Stop *> $null
        Write-Host "$($cmd.Description)" -ForegroundColor Cyan
    }
    Write-Host "3) Starting HiveMQ Edge service..."
    Start-Sleep -Seconds 5
    Start-Process -FilePath $nssmPath -ArgumentList 'start', 'HiveMQEdgeService' | Out-Null
    While ($true) {
        $status = (Get-Service -Name HiveMQEdgeService).Status
        Write-Host "HiveMQ Edge Service Status: $status" -ForegroundColor Cyan
        Start-Sleep -Seconds 5
        if ($status -eq 'Running') {
            Write-Host "HiveMQ Edge Service has been created and started successfully!" -ForegroundColor Green
            break
        }
    }
} catch {
    Write-Host "Failed to create and start HiveMQ Edge service." -ForegroundColor Red
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
