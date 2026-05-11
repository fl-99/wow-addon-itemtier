param(
    [string]$OutputDir = "dist",
    [string]$ZipName,
    [string]$ProjectVersion,
    [switch]$CleanOutput
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-PackageAs {
    param([string]$PkgmetaPath)

    if (-not (Test-Path -LiteralPath $PkgmetaPath)) {
        throw "Missing .pkgmeta at $PkgmetaPath"
    }

    $line = Select-String -Path $PkgmetaPath -Pattern '^\s*package-as\s*:\s*(.+?)\s*$' | Select-Object -First 1
    if (-not $line) {
        throw "Could not find 'package-as' in .pkgmeta"
    }

    return $line.Matches[0].Groups[1].Value.Trim()
}

function Get-PkgmetaIgnoreEntries {
    param([string]$PkgmetaPath)

    $entries = @()
    $lines = Get-Content -LiteralPath $PkgmetaPath
    $inIgnoreBlock = $false

    foreach ($line in $lines) {
        if ($line -match '^\s*ignore\s*:\s*$') {
            $inIgnoreBlock = $true
            continue
        }

        if ($inIgnoreBlock) {
            if ($line -match '^\s*-\s*(.+?)\s*$') {
                $entries += $Matches[1].Trim()
                continue
            }

            if ($line -match '^\S') {
                break
            }
        }
    }

    return $entries
}

function Get-ResolvedVersion {
    if ($ProjectVersion) {
        return $ProjectVersion
    }

    try {
        $tag = (git describe --tags --always --dirty 2>$null)
        if ($LASTEXITCODE -eq 0 -and $tag) {
            return $tag.Trim()
        }
    }
    catch {
        # ignore and use fallback
    }

    return "local-dev"
}

function Should-SkipFile {
    param(
        [string]$RelativePath,
        [string[]]$IgnorePatterns,
        [string[]]$SkipRootDirs
    )

    $normalized = $RelativePath -replace '\\', '/'

    if ($normalized -eq '.pkgmeta') {
        return $true
    }

    foreach ($rootDir in $SkipRootDirs) {
        if ($normalized -eq $rootDir -or $normalized.StartsWith("$rootDir/")) {
            return $true
        }
    }

    foreach ($pattern in $IgnorePatterns) {
        $p = ($pattern -replace '\\', '/').Trim('/')
        if (-not $p) {
            continue
        }

        if ($p.Contains('*') -or $p.Contains('?')) {
            if ($normalized -like $p) {
                return $true
            }
        }
        else {
            if ($normalized -eq $p -or $normalized.StartsWith("$p/")) {
                return $true
            }
        }
    }

    return $false
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptDir
$pkgmetaPath = Join-Path $repoRoot ".pkgmeta"

$packageAs = Get-PackageAs -PkgmetaPath $pkgmetaPath
$ignoreEntries = Get-PkgmetaIgnoreEntries -PkgmetaPath $pkgmetaPath
$version = Get-ResolvedVersion

if (-not $ZipName) {
    $ZipName = "$packageAs-$version.zip"
}

$outputPath = if ([System.IO.Path]::IsPathRooted($OutputDir)) {
    $OutputDir
}
else {
    Join-Path $repoRoot $OutputDir
}

$stagingRoot = Join-Path $outputPath ".staging"
$stagingAddonDir = Join-Path $stagingRoot $packageAs
$zipPath = Join-Path $outputPath $ZipName

if ($CleanOutput -and (Test-Path -LiteralPath $outputPath)) {
    Remove-Item -LiteralPath $outputPath -Recurse -Force
}

New-Item -ItemType Directory -Path $stagingAddonDir -Force | Out-Null

$skipRootDirs = @('.git', '.github', $packageAs, 'dist', 'build', 'release')
$sourceFiles = Get-ChildItem -LiteralPath $repoRoot -File -Recurse -Force
$copiedCount = 0

foreach ($file in $sourceFiles) {
    $relativePath = $file.FullName.Substring($repoRoot.Length + 1)
    if (Should-SkipFile -RelativePath $relativePath -IgnorePatterns $ignoreEntries -SkipRootDirs $skipRootDirs) {
        continue
    }

    $destPath = Join-Path $stagingAddonDir $relativePath
    $destDir = Split-Path -Parent $destPath
    if (-not (Test-Path -LiteralPath $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }

    Copy-Item -LiteralPath $file.FullName -Destination $destPath -Force
    $copiedCount++
}

$stagedTocPath = Join-Path $stagingAddonDir "$packageAs.toc"
if (Test-Path -LiteralPath $stagedTocPath) {
    $toc = Get-Content -LiteralPath $stagedTocPath -Raw
    $toc = $toc.Replace('@project-version@', $version)
    Set-Content -LiteralPath $stagedTocPath -Value $toc -NoNewline
}

if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}

Compress-Archive -Path $stagingAddonDir -DestinationPath $zipPath -CompressionLevel Optimal
Remove-Item -LiteralPath $stagingRoot -Recurse -Force

Write-Host "Created package: $zipPath"
Write-Host "Package folder: $packageAs"
Write-Host "Version value: $version"
Write-Host "Files copied: $copiedCount"
