$ErrorActionPreference = "Stop"

$modXmlPath = ".\src\mod.xml"

if (-not (Test-Path $modXmlPath)) {
  throw "Cannot find $modXmlPath. The mod source must live in .\src with mod.xml at its root."
}

# Validate the XML is well formed. This fails the build early instead of
# producing a broken .iroj that Junction VIII cannot read.
Write-Output "Validating $modXmlPath ..."
$xml = New-Object System.Xml.XmlDocument
try {
  $xml.Load((Resolve-Path $modXmlPath).Path)
}
catch {
  throw "mod.xml is not valid XML: $($_.Exception.Message)"
}

$modVersion = $xml.ModInfo.Version
if ([string]::IsNullOrWhiteSpace($modVersion)) {
  throw "<Version> is missing or empty in mod.xml"
}
$modVersion = $modVersion.Trim()

if ($modVersion -notmatch '^\d{4}\.\d{4}$') {
  throw "<Version> is '$modVersion' but must be a date in YYYY.MMDD form, for example 2026.0705"
}

$releaseVersion = "v$modVersion"

Write-Output "--------------------------------------------------"
Write-Output "MOD VERSION     : $modVersion"
Write-Output "RELEASE VERSION : $releaseVersion"
Write-Output "--------------------------------------------------"

Add-Content -Path $env:GITHUB_ENV -Value "_MOD_VERSION=$modVersion"
Add-Content -Path $env:GITHUB_ENV -Value "_RELEASE_VERSION=$releaseVersion"
