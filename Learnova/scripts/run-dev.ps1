$ErrorActionPreference = "Stop"

# Find the Learnova project root.
$projectRoot = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $projectRoot ".env"

# Stop if the private .env file does not exist.
if (-not (Test-Path $envFile)) {
    throw "The .env file was not found at: $envFile"
}

Write-Host "Loading development environment variables..."

foreach ($rawLine in Get-Content $envFile) {
    $line = $rawLine.Trim()

    # Ignore blank lines and comments.
    if ([string]::IsNullOrWhiteSpace($line)) {
        continue
    }

    if ($line.StartsWith("#")) {
        continue
    }

    # Split only at the first equals sign.
    $separatorIndex = $line.IndexOf("=")

    if ($separatorIndex -lt 1) {
        throw "Invalid .env line: $line"
    }

    $name = $line.Substring(0, $separatorIndex).Trim()
    $value = $line.Substring($separatorIndex + 1).Trim()

    # Remove matching outer quotation marks, when present.
    if (
        ($value.StartsWith('"') -and $value.EndsWith('"')) -or
        ($value.StartsWith("'") -and $value.EndsWith("'"))
    ) {
        $value = $value.Substring(1, $value.Length - 2)
    }

    [Environment]::SetEnvironmentVariable(
        $name,
        $value,
        [EnvironmentVariableTarget]::Process
    )
}

# Fail fast if required settings are still placeholders from .env.example.
$requiredSettings = @(
    @{ Name = "DB_URL";      Hint = "your Neon PostgreSQL connection string, e.g. jdbc:postgresql://host-pool...neon.tech/learnova_db?sslmode=require" },
    @{ Name = "DB_USERNAME"; Hint = "the database role (Neon user) used to connect" },
    @{ Name = "DB_PASSWORD"; Hint = "the password for DB_USERNAME" },
    @{ Name = "JWT_SECRET";  Hint = "a long random string used to sign access tokens (HS256)" }
)

$placeholderPattern = '(?i)(host-pool|your_neon|replace-with|changeme|ChangeMe|your_|placeholder|example)'
$missing = @()
$placeholder = @()

foreach ($setting in $requiredSettings) {
    $value = [Environment]::GetEnvironmentVariable($setting.Name, [EnvironmentVariableTarget]::Process)
    if ([string]::IsNullOrWhiteSpace($value)) {
        $missing += $setting
    }
    elseif ($value -match $placeholderPattern) {
        $placeholder += $setting
    }
}

if ($missing.Count -gt 0 -or $placeholder.Count -gt 0) {
    Write-Host ""
    Write-Host "Learnova cannot start: .env is not configured yet." -ForegroundColor Red
    Write-Host "The .env file at '$envFile' still has missing or placeholder values." -ForegroundColor Yellow
    Write-Host ""

    foreach ($setting in $missing) {
        Write-Host "  - $($setting.Name) is MISSING. Set it to $($setting.Hint)." -ForegroundColor Yellow
    }
    foreach ($setting in $placeholder) {
        Write-Host "  - $($setting.Name) is still a placeholder ('$([Environment]::GetEnvironmentVariable($setting.Name, [EnvironmentVariableTarget]::Process))'). Set it to $($setting.Hint)." -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Copy .env.example to .env, fill in real values, then re-run this script." -ForegroundColor Cyan
    Write-Host "A Neon free-tier PostgreSQL project works out of the box. Never commit .env." -ForegroundColor Cyan
    exit 1
}

# Fail fast if the configured port is already taken (e.g. a leftover
# dev server from a previous run). Spring Boot would otherwise fail
# after a long Maven build with a generic "port in use" error.
$serverPort = [Environment]::GetEnvironmentVariable("PORT", [EnvironmentVariableTarget]::Process)
if ([string]::IsNullOrWhiteSpace($serverPort)) {
    $serverPort = "8000"
}

$listener = Get-NetTCPConnection -LocalPort $serverPort -State Listen -ErrorAction SilentlyContinue
if ($listener) {
    $processId = ($listener | Select-Object -First 1).OwningProcess
    $processName = (Get-Process -Id $processId -ErrorAction SilentlyContinue).ProcessName
    Write-Host ""
    Write-Host "Learnova cannot start: port $serverPort is already in use." -ForegroundColor Red
    Write-Host "Process $processId ($processName) is listening on port $serverPort - this is usually a" -ForegroundColor Yellow
    Write-Host "dev server left over from a previous run." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Stop it with:  Stop-Process -Id $processId -Force" -ForegroundColor Cyan
    Write-Host "Then re-run this script. (Or set a different PORT in .env.)" -ForegroundColor Cyan
    exit 1
}

Write-Host "Environment variables loaded and validated."
Write-Host "Starting Learnova with the development profile..."

Push-Location $projectRoot

try {
    mvn spring-boot:run
}
finally {
    Pop-Location
}