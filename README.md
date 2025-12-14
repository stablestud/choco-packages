[![](https://ci.appveyor.com/api/projects/status/github/stablestud/chocolatey-packages?svg=true)](https://ci.appveyor.com/project/stablestud/chocolatey-packages)
[Update status](https://gist.github.com/stablestud/226bf7a893a53f1ee1eda1d3e78bf1bd)
[![](http://transparent-favicon.info/favicon.ico)](#)
[chocolatey/stablestud](https://chocolatey.org/profiles/stablestud)

This repository contains [chocolatey automatic packages](https://chocolatey.org/docs/automatic-packages).  

## Prerequisites

To run locally you will need:

- Powershell 5+.
- [Chocolatey Automatic Package Updater Module](https://github.com/majkinetor/au): `Install-Module chocolatey-au` or `choco install chocolatey-au`

## Update Packages Manually:

### Single package

To update a single package manually, `cd` into package subfolder and run:
`.\update.ps1`

Build NuGet package:
`choco pack`

### All packages

To update all packages run:
`.\update_all.ps1`

To also push packages to Chocolatey:
`$env:API_KEY="CHOCOLATEY_API_KEY"; .\update_all.ps1 -ChocoPush`
