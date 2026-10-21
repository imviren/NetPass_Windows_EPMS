<#
.SYNOPSIS
    Verifies the cryptographic integrity of downloaded NetPass EPMS installers against SHA256SUMS.txt.
.DESCRIPTION
    Computes the SHA-256 hash of EndpointHubServerSetup.exe and EndpointHubAgent.msi
    and verifies that they exactly match the published cryptographic signatures.
#>

param(
    [string]$InstallersDir = (Join-Path $PSScriptRoot "..\installers")
)

$ErrorActionPreference = "Stop"

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "   NetPass Windows EPMS — Installer Integrity Verification      " -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

$checksumFile = Join-Path $InstallersDir "SHA256SUMS.txt"
if (-not (Test-Path $checksumFile)) {
    Write-Host "[ERROR] Checksum file not found: $checksumFile" -ForegroundColor Red
    exit 1
}

$expectedHashes = @{}
Get-Content $checksumFile | ForEach-Object {
    $line = $_.Trim()
    if ($line -and -not $line.StartsWith("#")) {
        $parts = $line -split "\s+"
        if ($parts.Count -ge 2) {
            $expectedHashes[$parts[1]] = $parts[0].ToLower()
        }
    }
}

$allValid = $true

foreach ($fileName in $expectedHashes.Keys) {
    $filePath = Join-Path $InstallersDir $fileName
    if (-not (Test-Path $filePath)) {
        Write-Host "[MISSING] $fileName is not present in $InstallersDir" -ForegroundColor Yellow
        $allValid = $false
        continue
    }

    $actualHash = (Get-FileHash -Path $filePath -Algorithm SHA256).Hash.ToLower()
    $expectedHash = $expectedHashes[$fileName]

    if ($actualHash -eq $expectedHash) {
        Write-Host "[MATCH]   $fileName" -ForegroundColor Green
        Write-Host "          SHA256: $actualHash" -ForegroundColor DarkGray
    } else {
        Write-Host "[FAILED]  $fileName checksum mismatch!" -ForegroundColor Red
        Write-Host "          Expected: $expectedHash" -ForegroundColor Yellow
        Write-Host "          Actual:   $actualHash" -ForegroundColor Red
        $allValid = $false
    }
}

Write-Host ""
if ($allValid) {
    Write-Host "SUCCESS: All installer binaries verified successfully!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "WARNING: Verification failed. Do not execute untrusted binaries." -ForegroundColor Red
    exit 1
}
