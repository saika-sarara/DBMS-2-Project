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

Write-Host "Environment variables loaded."
Write-Host "Starting Learnova with the development profile..."

Push-Location $projectRoot

try {
    mvn spring-boot:run
}
finally {
    Pop-Location
}