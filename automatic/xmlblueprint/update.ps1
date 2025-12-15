Import-Module chocolatey-au

function Get-VersionFromUrl {
    param (
        [string]$Url
    )

    # Extract filename from the Location URL
    $filename = [System.IO.Path]::GetFileName($Url)

    # Check if the filename matches the expected pattern for version
    if (-not ($filename -match '^xmlblueprint-(\d+\.\d+\.\d+\.\d+)\.exe$')) {
        throw "Version format not found in filename: $filename"
    }

    # Extract and return the version from the matched pattern
    return $matches[1]
}

function Get-NextRedirectLocation {
    param (
        [string]$Url
    )

    # Send a HEAD request and prevent redirects; throw an error if request fails
    $response = Invoke-WebRequest -Uri $Url -Method Head -MaximumRedirection 0 -ErrorAction SilentlyContinue

    # Check if Location header is missing
    if (-not $response.Headers["Location"]) {
        throw "Location header not found in response."
    }

    # Extract the 'Location' header which contains the final URL after a possible redirect
    $location = $response.Headers["Location"]
    return $location
}

function global:au_GetLatest {
    $url = "https://www.xmlblueprint.com/update/download-64bit.php"
    $download = Get-NextRedirectLocation -Url $url
    $version = Get-VersionFromUrl -Url $download

    return @{ Version = $version; Url = $download }
}

function global:au_SearchReplace {
    return @{
        "tools\chocolateyinstall.ps1" = @{
            "(^[$]url\s*=\s*)('.*')"      = "`$1'$($Latest.Url)'"
            "(^[$]checksum\s*=\s*)('.*')" = "`$1'$($Latest.Checksum64)'"
        }
    }
}

Update-Package -NoReadme -NoCheckChocoVersion
