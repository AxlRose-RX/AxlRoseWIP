$ErrorActionPreference = "Stop"

# The versioned preview and the README banner have to live in the branch,
# because the catalog serves the image from raw.githubusercontent.com.

git config user.name  "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

git add preview README.md
if ($LASTEXITCODE -ne 0) { throw "git add failed with exit code $LASTEXITCODE" }

$pending = git diff --cached --name-only
if ([string]::IsNullOrWhiteSpace($pending)) {
  Write-Output "Preview and README already up to date, nothing to commit."
  return
}

Write-Output "Committing:"
$pending -split "`n" | Where-Object { $_ } | ForEach-Object { Write-Output "  $_" }

git commit -m "Preview for $env:_RELEASE_VERSION"
if ($LASTEXITCODE -ne 0) { throw "git commit failed with exit code $LASTEXITCODE" }

git push origin "HEAD:$env:GITHUB_REF_NAME"
if ($LASTEXITCODE -ne 0) { throw "git push failed with exit code $LASTEXITCODE" }

Write-Output "Pushed to $env:GITHUB_REF_NAME"
