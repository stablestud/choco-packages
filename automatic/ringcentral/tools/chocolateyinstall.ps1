$ErrorActionPreference = 'Stop'
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$url64      = 'https://app.ringcentral.com/download/RingCentral-x64.msi'
$checksum64 = 'FF199933FF4E31A7FA44970BDACD880CDCE67D28077A4C679CA90FF6B3BD2C56'
$checksumType64 = 'sha256'

$packageArgs = @{
  packageName   = $env:ChocolateyPackageName
  unzipLocation = $toolsDir
  softwareName  = 'RingCentral'
  fileType      = 'MSI'
  url64bit      = $url64
  checksum64      = $checksum64
  checksumType64  = $checksumType64
  silentArgs    = "/qn /norestart /l*v `"$($env:TEMP)\$($packageName).$($env:chocolateyPackageVersion).MsiInstall.log`""
  validExitCodes= @(0, 3010, 1641)
}

Install-ChocolateyPackage @packageArgs
