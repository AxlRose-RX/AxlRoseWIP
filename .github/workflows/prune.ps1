$ErrorActionPreference = "Stop"

$keep = $env:_RELEASE_VERSION
if ([string]::IsNullOrWhiteSpace($keep)) { throw "_RELEASE_VERSION is not set" }

Write-Output "Keeping release '$keep', removing everything else ..."

$json = gh release list --limit 200 --json tagName
if ($LASTEXITCODE -ne 0) { throw "gh release list failed with exit code $LASTEXITCODE" }

$releases = @()
if (-not [string]::IsNullOrWhiteSpace($json)) {
  $releases = @($json | ConvertFrom-Json)
}

if ($releases.Count -le 1) {
  Write-Output "  nothing to prune"
  return
}

foreach ($r in $releases) {
  if ($r.tagName -eq $keep) { continue }

  Write-Output "  deleting $($r.tagName) ..."
  gh release delete $r.tagName --yes --cleanup-tag
  if ($LASTEXITCODE -ne 0) {
    Write-Warning "  could not delete $($r.tagName), continuing"
  }
}

Write-Output "Done."
