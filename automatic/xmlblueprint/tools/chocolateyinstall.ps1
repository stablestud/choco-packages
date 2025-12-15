$ErrorActionPreference = 'Stop'
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$url        = 'https://filedn.eu/l6hrQdIONMfS36XFW6FwzhS/xmlblueprint-22.2025.10.30.exe'
$checksum   = '50631c91e192c7c7d44a80166702158d39f8e8b4c46f51e5563dca48549c8e95'
$packageArgs = @{
    packageName   = $env:ChocolateyPackageName
    unzipLocation = $toolsDir
    fileType      = 'EXE'
    url           = $url
    softwareName  = 'XMLBlueprint*'
    checksum      = $checksum
    checksumType  = 'sha256'
    silentArgs    = '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-'
    validExitCodes = @(0)
}

Install-ChocolateyPackage @packageArgs
