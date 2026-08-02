$ErrorActionPreference = "Stop"

$modXmlPath      = ".\src\mod.xml"
$catalogMetaPath = ".\catalog-meta.xml"
$previewPath     = ".\src\Preview\preview.png"
$previewDir      = ".\preview"
$readmePath      = ".\README.md"
$distDir         = ".\.dist"

$releaseName = $env:_RELEASE_NAME
$modVersion  = $env:_MOD_VERSION

$irojName = "$releaseName.iroj"
$archName = "$releaseName.7z"

$repo = $env:GITHUB_REPOSITORY   # e.g. AxlRose-RX/AxlRoseWIP
if ([string]::IsNullOrWhiteSpace($repo)) { throw "GITHUB_REPOSITORY is not set" }

$downloadBase = "https://github.com/$repo/releases/latest/download"

$branch = $env:GITHUB_REF_NAME   # e.g. canary
if ([string]::IsNullOrWhiteSpace($branch)) { throw "GITHUB_REF_NAME is not set" }

# --------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------

# Pull the raw inner text of a tag straight out of the file rather than
# through an XML parser, so whatever escaping is used in mod.xml
# (&#40; &#45; &apos; and friends) is carried into the catalog untouched.
function Get-RawNode {
  param(
    [Parameter(Mandatory = $true)] [string] $Content,
    [Parameter(Mandatory = $true)] [string] $Tag,
    [switch] $Optional
  )

  $m = [regex]::Match($Content, "<$Tag>(.*?)</$Tag>", 'Singleline')
  if (-not $m.Success) {
    if ($Optional) { return $null }
    throw "<$Tag> was not found in mod.xml"
  }
  return $m.Groups[1].Value
}

# --------------------------------------------------------------------
# 1. Build the .iroj
# --------------------------------------------------------------------

if (Test-Path $distDir) { Remove-Item $distDir -Recurse -Force }
New-Item -ItemType Directory -Path $distDir | Out-Null

Write-Output "Packing .\src into $irojName ..."
iroga pack .\src --output "$distDir\$irojName"
if ($LASTEXITCODE -ne 0) { throw "iroga pack failed with exit code $LASTEXITCODE" }

$irojLen = (Get-Item "$distDir\$irojName").Length
Write-Output ("  {0} : {1:N0} bytes" -f $irojName, $irojLen)

# --------------------------------------------------------------------
# 2. Compress the .iroj into the .7z
#    Mirrors the local settings: level 9 Ultra, LZMA2, 256 MB dictionary,
#    word size 64, 16 GB solid block. Threads are capped at 2 because the
#    runner has 16 GB of RAM and a 256 MB dictionary needs roughly 2.7 GB
#    per thread.
# --------------------------------------------------------------------

Write-Output "Compressing $irojName into $archName ..."
Push-Location $distDir
try {
  7z a -t7z -mx=9 -m0=lzma2:d256m:fb64 -ms=16g -mmt=2 "$archName" "$irojName"
  if ($LASTEXITCODE -ne 0) { throw "7z failed with exit code $LASTEXITCODE" }
}
finally {
  Pop-Location
}

$archLen = (Get-Item "$distDir\$archName").Length
# Junction VIII reads DownloadSize in KB, matching what Explorer shows.
$downloadSize = [math]::Ceiling($archLen / 1024)

Write-Output ("  {0} : {1:N0} bytes ({2:N0} KB)" -f $archName, $archLen, $downloadSize)

# The .iroj is only an intermediate. It is often over the 2 GiB per-file
# release limit and is never uploaded, so drop it now to free runner disk.
Remove-Item "$distDir\$irojName" -Force

# --------------------------------------------------------------------
# 3. Publish a versioned copy of the preview image
#
#    Not a release asset: those are served as application/octet-stream with
#    an attachment disposition, so catalog-driven sites cannot embed them.
#    The raw URL below serves image/png inline and can be reused anywhere.
#
#    The copy is versioned so that a new release never collides with a cached
#    older image, and it lives OUTSIDE src\ so iroga never packs the growing
#    pile of old previews into the .iroj.
# --------------------------------------------------------------------

if (-not (Test-Path $previewPath)) {
  throw "Cannot find $previewPath. The catalog PreviewImage is served from this file."
}

if (-not (Test-Path $previewDir)) { New-Item -ItemType Directory -Path $previewDir | Out-Null }

$previewName = "preview_$env:_RELEASE_VERSION.png"
Copy-Item $previewPath (Join-Path $previewDir $previewName) -Force
Write-Output "Preview published as preview/$previewName"

# --------------------------------------------------------------------
# 4. Generate catalog-mod.xml
# --------------------------------------------------------------------

$mod = Get-Content $modXmlPath -Raw

# Only look at the header block, above the first Compatibility / ModFolder /
# ConfigOption section, so tags reused further down are never picked up.
$cut = [regex]::Match($mod, '<(Compatibility|ModFolder|ConfigOption)\b')
if ($cut.Success) { $mod = $mod.Substring(0, $cut.Index) }

$modId          = (Get-RawNode $mod 'ID').Trim()
$modName        = (Get-RawNode $mod 'Name').Trim()
$modAuthor      = (Get-RawNode $mod 'Author').Trim()
$modCategory    = (Get-RawNode $mod 'Category').Trim()
$modDescription = Get-RawNode $mod 'Description'
$modNotes       = Get-RawNode $mod 'ReleaseNotes'
$modDate        = (Get-RawNode $mod 'ReleaseDate').Trim()
$modLink        = (Get-RawNode $mod 'Link').Trim()
$modDonation    = (Get-RawNode $mod 'DonationLink' -Optional)
if ($modDonation) { $modDonation = $modDonation.Trim() }

if (-not (Test-Path $catalogMetaPath)) { throw "Cannot find $catalogMetaPath" }
$meta = New-Object System.Xml.XmlDocument
$meta.Load((Resolve-Path $catalogMetaPath).Path)

$compatible = $meta.CatalogMeta.CompatibleGameVersions
if ([string]::IsNullOrWhiteSpace($compatible)) { throw "<CompatibleGameVersions> is empty in catalog-meta.xml" }
$compatible = $compatible.Trim()

$tags = @($meta.CatalogMeta.Tags.string | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
if ($tags.Count -eq 0) { throw "No <string> tags found in catalog-meta.xml" }

# Junction VIII expects :// written as $ inside an iroj:// link.
$downloadLink = "iroj://Url/https`$github.com/$repo/releases/latest/download/$archName"
$previewImage = "https://raw.githubusercontent.com/$repo/$branch/preview/$previewName"

$sb = New-Object System.Text.StringBuilder
[void]$sb.Append("<?xml version=`"1.0`"?>`n")
[void]$sb.Append("<Mod>`n")
[void]$sb.Append("  <ID>$modId</ID>`n")
[void]$sb.Append("  <Name>$modName</Name>`n")
[void]$sb.Append("  <Author>$modAuthor</Author>`n")
[void]$sb.Append("  <Category>$modCategory</Category>`n")
[void]$sb.Append("  <Description>$modDescription</Description>`n")
[void]$sb.Append("  <LatestVersion>`n")
[void]$sb.Append("    <Link>$downloadLink</Link>`n")
[void]$sb.Append("    <Version>$modVersion</Version>`n")
[void]$sb.Append("    <ReleaseDate>$modDate</ReleaseDate>`n")
[void]$sb.Append("    <CompatibleGameVersions>$compatible</CompatibleGameVersions>`n")
[void]$sb.Append("    <PreviewImage>$previewImage</PreviewImage>`n")
[void]$sb.Append("    <ReleaseNotes>$modNotes</ReleaseNotes>`n")
[void]$sb.Append("    <DownloadSize>$downloadSize</DownloadSize>`n")
[void]$sb.Append("  </LatestVersion>`n")
[void]$sb.Append("  <Link>$modLink</Link>`n")
if ($modDonation) {
  [void]$sb.Append("  <DonationLink>$modDonation</DonationLink>`n")
}
[void]$sb.Append("  <Tags>`n")
foreach ($t in $tags) {
  [void]$sb.Append("    <string>$($t.Trim())</string>`n")
}
[void]$sb.Append("  </Tags>`n")
[void]$sb.Append("</Mod>`n")

$catalogXml = $sb.ToString() -replace "`r`n", "`n"

# Sanity check: the file we just built has to parse.
$check = New-Object System.Xml.XmlDocument
try {
  $check.LoadXml($catalogXml)
}
catch {
  throw "Generated catalog-mod.xml is not valid XML: $($_.Exception.Message)"
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText((Join-Path (Resolve-Path $distDir) "catalog-mod.xml"), $catalogXml, $utf8NoBom)

# --------------------------------------------------------------------
# 5. Decode mod.xml text for humans
#
#    mod.xml escapes everything (&#40; &#45; &apos; ...) because Junction VIII
#    reads it raw. GitHub does not, so decode once and reuse.
# --------------------------------------------------------------------

function Get-DecodedText {
  param([string] $Value)

  $text = [System.Net.WebUtility]::HtmlDecode($Value)
  $text = $text -replace "`r`n", "`n"
  $lines = @($text -split "`n" | ForEach-Object { $_.TrimEnd() })
  return ($lines -join "`n").Trim()
}

$nameText  = Get-DecodedText $modName
$notesText = Get-DecodedText $modNotes

# The description becomes markdown, so left-align it and make sure the bullet
# list is preceded by a blank line.
$descLines = @()
$prev = ""
foreach ($line in ((Get-DecodedText $modDescription) -split "`n")) {
  $t = $line.Trim()
  if ($t.StartsWith("-") -and $prev -ne "" -and -not $prev.StartsWith("-")) {
    $descLines += ""
  }
  $descLines += $t
  $prev = $t
}
$descText = ($descLines -join "`n").Trim()

# --------------------------------------------------------------------
# 6. Regenerate the README intro block
#
#    Everything between the two markers is built from mod.xml, so the banner,
#    the blurb and the latest release notes never go stale. Everything outside
#    the markers is hand written and is left alone.
# --------------------------------------------------------------------

$startMark = "<!-- INTRO:START -->"
$endMark   = "<!-- INTRO:END -->"

$intro = @"

<p align="center">
  <img src="preview/$previewName" alt="$nameText">
</p>

$descText

## Latest release: $env:_RELEASE_VERSION

``````
$notesText
``````

"@

if (Test-Path $readmePath) {
  $readme = (Get-Content $readmePath -Raw) -replace "`r`n", "`n"

  $si = $readme.IndexOf($startMark)
  $ei = $readme.IndexOf($endMark)
  if ($si -lt 0 -or $ei -lt 0 -or $ei -lt $si) {
    throw "README.md is missing the $startMark / $endMark markers, cannot regenerate the intro block."
  }

  $updated = $readme.Substring(0, $si + $startMark.Length) +
             (($intro -replace "`r`n", "`n")) +
             $readme.Substring($ei)

  if ($updated -ne $readme) {
    [System.IO.File]::WriteAllText((Resolve-Path $readmePath).Path, $updated, $utf8NoBom)
    Write-Output "README intro block regenerated for $env:_RELEASE_VERSION"
  }
}

# --------------------------------------------------------------------
# 7. Release notes body
#
#    The banner is pulled from raw.githubusercontent rather than being an
#    attached asset, so it renders inline on the release page. It is already
#    committed to the branch by commit-preview.ps1, which runs before the
#    release is published.
# --------------------------------------------------------------------

$body = @"
<p align="center">
  <img src="$previewImage" alt="$nameText $env:_RELEASE_VERSION">
</p>

**$nameText** $env:_RELEASE_VERSION

``````
$notesText
``````

Download: ``$archName`` ($([math]::Round($archLen / 1MB, 1)) MB)
"@
[System.IO.File]::WriteAllText((Join-Path (Resolve-Path $distDir) "release-notes.md"), ($body -replace "`r`n", "`n"), $utf8NoBom)

# --------------------------------------------------------------------

Write-Output "--------------------------------------------------"
Write-Output "Release artifacts:"
Get-ChildItem $distDir | ForEach-Object { Write-Output ("  {0,-20} {1,15:N0} bytes" -f $_.Name, $_.Length) }
Write-Output "--------------------------------------------------"
Write-Output "Catalog link : $downloadLink"
Write-Output "Preview image: $previewImage"
Write-Output "DownloadSize : $downloadSize"
Write-Output "--------------------------------------------------"
Write-Output $catalogXml
