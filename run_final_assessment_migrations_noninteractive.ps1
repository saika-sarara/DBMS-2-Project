<#
Non-interactive PowerShell script to run final assessment SQL migrations (V23 then V24).
Reads DB connection info from a .env file or environment variables.

Usage:
  1) Create a .env file at the repo root (do NOT commit it). Example .env content:
       PGHOST=localhost
       PGPORT=5432
       PGDATABASE=learnova_dev
       PGUSER=learnova_user
       PGPASSWORD=s3cret
  2) From the repository root run: .\run_final_assessment_migrations_noninteractive.ps1
  3) Optionally provide a path to a .env file: .\run_final_assessment_migrations_noninteractive.ps1 -EnvFilePath "C:\secrets\.env"

Security note: Do NOT commit your .env file. This script will not modify any files.
This is intended for automated/dev use where credentials are supplied via a secure file or environment.
#>

param(
    [string]$EnvFilePath = "$PSScriptRoot\.env",
    [switch]$RequireConfirmation
)

# Resolve script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

$migV23 = Join-Path $scriptDir "Learnova\src\main\resources\db\migration\V23__course_final_assessment.sql"
$migV24 = Join-Path $scriptDir "Learnova\src\main\resources\db\migration\V24__final_assessment_functions.sql"

function Abort($msg) {
    Write-Error $msg
    exit 1
}

function Read-EnvFile($path) {
    if (-not (Test-Path $path)) { return @{} }
    $pairs = @{}
    Get-Content $path | ForEach-Object {
        $line = $_.Trim()
        if ($line -eq '' -or $line.StartsWith('#')) { return }
        $idx = $line.IndexOf('=')
        if ($idx -lt 0) { return }
        $k = $line.Substring(0,$idx).Trim()
        $v = $line.Substring($idx+1).Trim()
        # Remove optional surrounding quotes
        if (($v.StartsWith('"') -and $v.EndsWith('"')) -or ($v.StartsWith("'") -and $v.EndsWith("'"))) {
            $v = $v.Substring(1,$v.Length-2)
        }
        $pairs[$k] = $v
    }
    return $pairs
}

# Check psql exists
if (-not (Get-Command psql -ErrorAction SilentlyContinue)) {
    Abort "psql not found in PATH. Install PostgreSQL client tools or add psql to PATH."
}

# Load .env if present
$envPairs = Read-EnvFile $EnvFilePath
if ($envPairs.Count -gt 0) {
    Write-Host "Loaded environment values from $EnvFilePath" -ForegroundColor Cyan
    foreach ($k in $envPairs.Keys) {
        if (-not [string]::IsNullOrEmpty($envPairs[$k])) { $env:$k = $envPairs[$k] }
    }
} else {
    Write-Host "No .env file found at $EnvFilePath; falling back to environment variables or prompts." -ForegroundColor Yellow
}

# Use environment variables or fail
$host = $env:PGHOST
$port = $env:PGPORT
$db = $env:PGDATABASE
$user = $env:PGUSER
$password = $env:PGPASSWORD

if (-not $host -or -not $db -or -not $user -or -not $password) {
    Abort "Missing required DB connection info. Provide a .env file with PGHOST, PGPORT, PGDATABASE, PGUSER, PGPASSWORD or set environment variables."
}

function Run-SqlFile($filePath) {
    if (-not (Test-Path $filePath)) { Abort "SQL file not found: $filePath" }
    Write-Host "\n--- Running migration: $filePath ---" -ForegroundColor Cyan
    $env:PGPASSWORD = $password
    & psql -h $host -p $port -U $user -d $db -v ON_ERROR_STOP=1 -f $filePath
    $code = $LASTEXITCODE
    if ($code -ne 0) {
        Abort "psql returned exit code $code while executing $filePath"
    }
    Write-Host "Completed: $filePath" -ForegroundColor Green
    $env:PGPASSWORD = $null
}

function Run-SqlQuery($sql) {
    Write-Host "\n--- SQL: $sql ---" -ForegroundColor Yellow
    $env:PGPASSWORD = $password
    & psql -h $host -p $port -U $user -d $db -c $sql
    $env:PGPASSWORD = $null
}

Write-Host "Starting non-interactive migrations against $user@$host:$port/$db" -ForegroundColor Magenta
if ($RequireConfirmation) {
    Write-Host "Confirmation required but this is non-interactive. Exiting." -ForegroundColor Red
    Exit 1
}

Run-SqlFile $migV23
Run-SqlFile $migV24

Run-SqlQuery "SELECT installed_rank, version, description, success, installed_on FROM public.flyway_schema_history ORDER BY installed_rank DESC LIMIT 20;"
Run-SqlQuery "SELECT proname FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE proname LIKE 'fn_final_assessment_%' OR proname LIKE 'sp_final_assessment_%' ORDER BY proname;"

Write-Host "\nNon-interactive migrations completed successfully." -ForegroundColor Green
exit 0
