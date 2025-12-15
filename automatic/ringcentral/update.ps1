Import-Module chocolatey-au

function Get-RemoteLastModifiedUnixTimestamp {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Url
    )

    try {
        # Send HEAD request
        $response = Invoke-WebRequest -Uri $Url -Method Head -UseBasicParsing

        # Get Last-Modified header
        $lastModified = $response.Headers["Last-Modified"]

        if (-not $lastModified) {
            throw "Last-Modified header not found."
        }

        # Parse to DateTime (UTC)
        $dateTime = [DateTime]::Parse($lastModified).ToUniversalTime()

        # Convert to Unix timestamp
        $unixTimestamp = [int64]([DateTimeOffset]$dateTime).ToUnixTimeSeconds()

        return $unixTimestamp
    }
    catch {
        Write-Error $_
        return $null
    }
}

function Get-MsiProductVersion {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ })]
        [string]$MsiPath
    )

    try {
        # Create Windows Installer COM object
        $installer = New-Object -ComObject WindowsInstaller.Installer

        # Open MSI database in read-only mode (0)
        $database = $installer.GetType().InvokeMember(
            "OpenDatabase",
            "InvokeMethod",
            $null,
            $installer,
            @($MsiPath, 0)
        )

        # Query ProductVersion from Property table
        $query = "SELECT Value FROM Property WHERE Property = 'ProductVersion'"
        $view = $database.GetType().InvokeMember(
            "OpenView",
            "InvokeMethod",
            $null,
            $database,
            ($query)
        )

        $view.GetType().InvokeMember("Execute", "InvokeMethod", $null, $view, $null)
        $record = $view.GetType().InvokeMember(
            "Fetch",
            "InvokeMethod",
            $null,
            $view,
            $null
        )

        if (-not $record) {
            throw "ProductVersion not found in MSI."
        }

        $version = [string]($record.StringData(1))
        $version = ($version -replace "`0", "").Trim()

        return $version
    }
    catch {
        Write-Error $_
        return $null
    }
}

function Download-FileFromUrl {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Url,

        [string]$DestinationFolder = $env:TEMP
    )

    try {
        # Ensure destination folder exists
        if (-not (Test-Path $DestinationFolder)) {
            New-Item -Path $DestinationFolder -ItemType Directory | Out-Null
        }

        # Get filename from URL
        $fileName = [System.IO.Path]::GetFileName($Url)
        if (-not $fileName) {
            # fallback to random name if URL ends with /
            $fileName = [System.Guid]::NewGuid().ToString()
        }

        $destinationPath = Join-Path $DestinationFolder $fileName

        # If file exists, try to remove it first
        if (Test-Path $destinationPath) {
            try {
                Remove-Item $destinationPath -Force -ErrorAction Stop
            } catch {
                Write-Warning "Existing file is in use. Trying a temporary name."
                $destinationPath = Join-Path $DestinationFolder ("temp_" + [System.Guid]::NewGuid().ToString())
            }
        }

        # Download file
        Write-Host "Downloading $fileName to $destinationPath"
        Start-BitsTransfer -Source $Url -Destination $destinationPath

        return $destinationPath
    }
    catch {
        Write-Error "Failed to download file: $_"
        return $null
    }
}

function Get-JsonValue {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ParameterName,

        [string]$JsonPath = (Join-Path $PSScriptRoot "state.json")
    )

    try {
        # Check if JSON file exists
        if (-not (Test-Path $JsonPath)) {
            throw "JSON file not found: $JsonPath"
        }

        # Load JSON
        $json = Get-Content $JsonPath -Raw | ConvertFrom-Json

        # Check if property exists
        if (-not $json.PSObject.Properties[$ParameterName]) {
            #throw "Property '$ParameterName' not found in JSON."
            return "0"
        }

        # Return value
        return $json.$ParameterName
    }
    catch {
        Write-Warning $_
        return "0"
    }
}

function Set-JsonValue {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ParameterName,

        [Parameter(Mandatory = $true)]
        $Value,

        [string]$JsonPath = (Join-Path $PSScriptRoot "state.json")
    )

    try {
        # If JSON file exists, load it; otherwise create new hashtable
        if (Test-Path $JsonPath) {
            $json = Get-Content $JsonPath -Raw | ConvertFrom-Json
            if (-not $json) { $json = [PSCustomObject]@{} }
        } else {
            $json = [PSCustomObject]@{}
        }

        # Ensure single value is not wrapped as array
        if ($Value -is [System.Array] -and $Value[0] -eq $null) {
            $Value = $Value[1]
        }

        # Add or update property
        $json | Add-Member -NotePropertyName $ParameterName -NotePropertyValue $Value -Force

        # Write back to disk
        $json | ConvertTo-Json -Depth 10 | Set-Content $JsonPath -Encoding UTF8
    }
    catch {
        Write-Error $_
    }
}

function global:au_GetLatest {
    $url = "https://app.ringcentral.com/download/RingCentral-x64.msi"

    $remoteTimestamp = Get-RemoteLastModifiedUnixTimestamp -Url $url
    $lastTimestamp = Get-JsonValue -ParameterName "lastModified"
    $lastVersion = Get-JsonValue -ParameterName "lastVersion"
    $lastChecksum = Get-JsonValue -ParameterName "lastChecksum"
    $lastChecksumType = Get-JsonValue -ParameterName "lastChecksumType"

    if ($remoteTimestamp -eq $lastTimestamp) {
        Write-Host "Remote file timestamp has not changed, therefore no update available"
        return @{ Version = $lastVersion; Url64 = $url; Checksum64 = $lastChecksum; ChecksumType64 = $lastChecksumType }
    }

    Write-Host "Remote file timestamp has changed: $remoteTimestamp != $lastTimestamp"

    $filePath = Download-FileFromUrl -Url $url
    $readVersion = Get-MsiProductVersion -MsiPath $filePath
    Write-Host "Read MSI ProductVersion: $readVersion"
    $v = [version][string]$readVersion
    $newVersion = "$($v.Major).$($v.Minor).$($v.Build)"
    Write-Host "Chocolatey adjusted version string: $newVersion"

    Set-JsonValue -ParameterName "lastModified" -Value $remoteTimestamp
    if ($newVersion -eq $lastVersion) {
        Write-Host "Remote file version has not changed, therefore no update available"
        return @{ Version = $lastVersion; Url64 = $url; Checksum64 = $lastChecksum; ChecksumType64 = $lastChecksumType }
    }

    Write-Host "Remote file version has changed: $newVersion != $lastVersion"

    $hash = Get-FileHash -Path $filePath -Algorithm 'SHA256'
    $newChecksum = $hash.Hash.ToUpper()
    $newChecksumType = $hash.Algorithm.ToLower()
    Set-JsonValue -ParameterName "lastVersion" -Value $newVersion
    Set-JsonValue -ParameterName "lastChecksum" -Value $newChecksum
    Set-JsonValue -ParameterName "lastChecksumType" -Value $newChecksumType
    return @{ Version = $newVersion; Url64 = $url; Checksum64 = $newChecksum; ChecksumType64 = $newChecksumType }
}

function global:au_SearchReplace {
    @{
        "tools\chocolateyinstall.ps1" = @{
            "(^[$]url64\s*=\s*)('.*')"      = "`$1'$($Latest.Url64)'"
            "(^[$]checksum64\s*=\s*)('.*')" = "`$1'$($Latest.Checksum64)'"
            "(^[$]checksumType64\s*=\s*)('.*')" = "`$1'$($Latest.ChecksumType64)'"
        }
    }
}

Update-Package -ChecksumFor none -NoReadme
