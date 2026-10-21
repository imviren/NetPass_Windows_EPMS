<#
.SYNOPSIS
    Automated silent installation helper for EndpointHub Client Agent.
.DESCRIPTION
    Installs EndpointHubAgent.msi silently using msiexec with preconfigured Server URL,
    optional enrollment token, and logging.
.PARAMETER ServerUrl
    The HTTPS base URL of the EndpointHub Server (e.g. https://epms.corp.local).
.PARAMETER EnrollmentToken
    Optional pre-shared enrollment token for zero-touch onboarding.
.PARAMETER MsiPath
    Path to EndpointHubAgent.msi. Defaults to the installers folder in this repository.
.EXAMPLE
    .\deploy-agent-silent.ps1 -ServerUrl "https://10.0.10.15"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ServerUrl,

    [Parameter(Mandatory = $false)]
    [string]$EnrollmentToken = "",

    [Parameter(Mandatory = $false)]
    [string]$MsiPath = (Join-Path $PSScriptRoot "..\installers\EndpointHubAgent.msi")
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $MsiPath)) {
    Write-Host "[ERROR] Agent MSI not found at: $MsiPath" -ForegroundColor Red
    exit 1
}

$logFile = "$env:TEMP\EndpointHubAgent_Install_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "   NetPass Windows EPMS — Silent Agent Deployment               " -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "Target Server URL: $ServerUrl"
Write-Host "Source MSI:        $MsiPath"
Write-Host "Install Log:       $logFile"
Write-Host ""

$msiArgs = @(
    "/i", "`"$MsiPath`"",
    "/qn",
    "/norestart",
    "/l*v", "`"$logFile`"",
    "SERVER_URL=`"$ServerUrl`""
)

if (-not [string]::IsNullOrWhiteSpace($EnrollmentToken)) {
    $msiArgs += "ENROLLMENT_TOKEN=`"$EnrollmentToken`""
}

Write-Host "Executing: msiexec.exe $($msiArgs -join ' ')" -ForegroundColor DarkGray
$proc = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru

if ($proc.ExitCode -eq 0) {
    Write-Host "[SUCCESS] EndpointHubAgent installed successfully." -ForegroundColor Green
    
    # Check if Windows service is registered
    $svc = Get-Service -Name "EndpointHubAgent" -ErrorAction SilentlyContinue
    if ($svc) {
        Write-Host "[SERVICE] EndpointHubAgent status: $($svc.Status)" -ForegroundColor Cyan
    }
    exit 0
} elseif ($proc.ExitCode -eq 3010) {
    Write-Host "[SUCCESS] EndpointHubAgent installed successfully (Reboot pending: ExitCode 3010)." -ForegroundColor Yellow
    exit 3010
} else {
    Write-Host "[ERROR] Installation failed with ExitCode: $($proc.ExitCode). Check log: $logFile" -ForegroundColor Red
    exit $proc.ExitCode
}
