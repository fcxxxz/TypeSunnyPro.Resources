param(
    [string]$OutputDir = "dist",
    [string]$Version = ""
)

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$packagesRoot = Join-Path $repoRoot "packages"
$outputRoot = Join-Path $repoRoot $OutputDir

function Get-BeijingVersion {
    $tz = [System.TimeZoneInfo]::FindSystemTimeZoneById("Asia/Shanghai")
    $now = [System.TimeZoneInfo]::ConvertTimeFromUtc([DateTime]::UtcNow, $tz)
    return $now.ToString("yyyyMMdd.HHmm", [System.Globalization.CultureInfo]::InvariantCulture)
}

function Get-UniqueVersion([string]$baseVersion, [string]$outputRoot) {
    $candidate = $baseVersion
    $suffix = 1
    while (Test-Path (Join-Path $outputRoot "manifest-$candidate.json")) {
        $candidate = "$baseVersion.$suffix"
        $suffix++
    }
    return $candidate
}

function Get-Sha256([string]$path) {
    return (Get-FileHash -Path $path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-GitHubUrl([string]$version, [string]$fileName) {
    return "https://github.com/fcxxxz/TypeSunnyPro.Resources/releases/download/v$version/$fileName"
}

function Get-GiteeUrl([string]$version, [string]$fileName) {
    return "https://gitee.com/fuchuxuan/typesunnypro-resources/releases/download/v$version/$fileName"
}

function New-PackageZip([string]$id, [string]$displayName, [string]$version, [string]$installTarget, [string]$entry) {
    $source = Join-Path $packagesRoot $id
    if (-not (Test-Path $source)) {
        throw "Missing package source: $source"
    }

    $zipName = "$id-$version.zip"
    $zipPath = Join-Path $outputRoot $zipName
    if (Test-Path $zipPath) {
        Remove-Item $zipPath -Force
    }

    Push-Location $packagesRoot
    try {
        Compress-Archive -Path $id -DestinationPath $zipPath -Force
    } finally {
        Pop-Location
    }

    return [ordered]@{
        id = $id
        name = $displayName
        version = $version
        size = (Get-Item $zipPath).Length
        sha256 = Get-Sha256 $zipPath
        min_app_version = "20260607.0000"
        install_target = $installTarget
        entry = $entry
        urls = @(
            (Get-GiteeUrl $version $zipName),
            (Get-GitHubUrl $version $zipName)
        )
    }
}

New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
$baseVersion = if ([string]::IsNullOrWhiteSpace($Version)) { Get-BeijingVersion } else { $Version }
$manifestVersion = Get-UniqueVersion $baseVersion $outputRoot

$packages = @(
    New-PackageZip "articles" "本地文章" $manifestVersion "articles" "articles"
    New-PackageZip "trainer-articles" "练单器" $manifestVersion "trainer-articles" "trainer-articles"
    New-PackageZip "shuang" "晴双拼" $manifestVersion "shuang" "shuang"
    New-PackageZip "ziti-basic" "字提基础包" $manifestVersion "ziti-basic" "ziti-basic"
    New-PackageZip "citi-basic" "词提基础包" $manifestVersion "citi-basic" "citi-basic"
)

$manifest = [ordered]@{
    schema_version = 1
    manifest_version = $manifestVersion
    generated_at = ([DateTime]::UtcNow.ToString("o", [System.Globalization.CultureInfo]::InvariantCulture))
    packages = $packages
}

$manifestJson = $manifest | ConvertTo-Json -Depth 8
$manifestJson | Set-Content -Path (Join-Path $outputRoot "manifest.json") -Encoding UTF8
$manifestJson | Set-Content -Path (Join-Path $outputRoot "manifest-$manifestVersion.json") -Encoding UTF8
$manifestVersion | Set-Content -Path (Join-Path $outputRoot "version.txt") -Encoding UTF8
Write-Host "Built resource manifest $manifestVersion in $outputRoot"
