Import-Module chocolatey-au

function Get-ArchiveStringsFromUrl {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Url
    )

    try {
        $content = (Invoke-WebRequest -Uri $Url -UseBasicParsing).Content
    }
    catch {
        throw "Failed to download content from '$Url'. $($_.Exception.Message)"
    }

    # Match quoted or unquoted strings containing 'xmlblueprint-archive'
    $matches = [regex]::Matches(
        $content,
        '(?i)(?:"([^"]*xmlblueprint-archive-[^"]*)"|''([^'']*xmlblueprint-archive-[^'']*)''|(\S*xmlblueprint-archive-\S*))'
    )

    $results = foreach ($match in $matches) {
        $match.Groups[1..3] | Where-Object { $_.Value } | ForEach-Object { $_.Value }
    }

    return $results |
        Sort-Object -Unique
}

function Get-HighestArchiveVersion {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string[]]$ArchiveStrings
    )

    $versions = foreach ($item in $ArchiveStrings) {
        if ($item -match 'xmlblueprint-archive-(\d+(?:\.\d+)+)') {
            try {
                [PSCustomObject]@{
                    Source  = $item
                    Version = [version]$matches[1]
                }
            }
            catch {
                # Skip invalid version formats
            }
        }
    }

    if (-not $versions) {
        throw 'No valid archive versions were found.'
    }

    return ($versions | Sort-Object Version -Descending | Select-Object -First 1)
}

function global:au_GetLatest {
    $url = "https://filedn.eu/l6hrQdIONMfS36XFW6FwzhS" # do not add a / slash to the URL end
    $archives = Get-ArchiveStringsFromUrl -Url $url
    $latest = Get-HighestArchiveVersion -ArchiveStrings $archives

    return @{ Version = $latest.Version; Url = "$url/$($latest.Source)" }
}

function global:au_SearchReplace {
    return @{
        "tools\chocolateyinstall.ps1" = @{
            "(^[$]url\s*=\s*)('.*')"      = "`$1'$($Latest.Url)'"
            "(^[$]checksum\s*=\s*)('.*')" = "`$1'$($Latest.Checksum64)'"
        }
    }
}

Update-Package -NoReadme
