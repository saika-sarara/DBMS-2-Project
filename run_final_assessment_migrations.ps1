<#
One-click PowerShell script to run the final assessment SQL migrations (V23 then V24)
Run this on a development/test Postgres instance only.
Usage:
  1) Open PowerShell.
  2) From the repository root run: .\run_final_assessment_migrations.ps1

The script reads PGHOST/PGPORT/PGDATABASE/PGUSER/PGPASSWORD from environment if present.
If not set it will prompt interactively for host, port, database, user and password.
The password prompt is secure and will not echo.

This script will:
 - verify psql is available
 - execute V23__course_final_assessment.sql (stops on error)
 - execute V24__final_assessment_functions.sql (stops on error)
 - run a small set of verification queries and print results

IMPORTANT:
 - Do NOT run against production. Confirm the DB is a dev/test instance.
 - This script will stop on the first SQL error.
#>

# Resolve script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Paths to migration files (relative to script location)
$migV23 = Join-Path $scriptDir "Learnova\src\main\resources\db\migration\V23__course_final_assessment.sql"
$migV24 = Join-Path $scriptDir "Learnova\src\main\resources\db\migration\V24__final_assessment_functions.sql"

function Abort($msg) {
    Write-Error $msg
    exit 1
}

# Check psql exists
if (-not (Get-Command psql -ErrorAction SilentlyContinue)) {
    Abort "psql not found in PATH. Install PostgreSQL client tools or add psql to PATH."
}

# Get connection info from env or prompt
$host = $env:PGHOST
if (-not $host) { $host = Read-Host "Postgres host (e.g. localhost)" }
$port = $env:PGPORT
if (-not $port) { $port = Read-Host "Postgres port (default 5432)"; if (-not $port) { $port = '5432' } }
$db = $env:PGDATABASE
if (-not $db) { $db = Read-Host "Database name" }
$user = $env:PGUSER
if (-not $user) { $user = Read-Host "Database user" }

if ($env:PGPASSWORD) {
    $password = $env:PGPASSWORD
} else {
    $secure = Read-Host -AsSecureString "Database password"
    try {
        $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
        $password = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    } finally {
        if ($ptr) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
    }
}

# Helper to run a SQL file via psql
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
    # Clear PGPASSWORD only from process env variable (retained in $password variable)
    $env:PGPASSWORD = $null
}

# Helper to run a single SQL command and display output
function Run-SqlQuery($sql) {
    Write-Host "\n--- SQL: $sql ---" -ForegroundColor Yellow
    $env:PGPASSWORD = $password
    & psql -h $host -p $port -U $user -d $db -c $sql
    $env:PGPASSWORD = $null
}

Write-Host "Starting final assessment migrations against $user@$host:$port/$db" -ForegroundColor Magenta

# Confirm with user
$confirm = Read-Host "This will apply new migrations to the database above. Type YES to continue"
if ($confirm -ne 'YES') { Abort 'Aborted by user.' }

# Run migrations sequentially
Run-SqlFile $migV23
Run-SqlFile $migV24

# Verification queries
Run-SqlQuery "SELECT installed_rank, version, description, success, installed_on FROM public.flyway_schema_history ORDER BY installed_rank DESC LIMIT 20;"
Run-SqlQuery "SELECT proname FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE proname LIKE 'fn_final_assessment_%' OR proname LIKE 'sp_final_assessment_%' ORDER BY proname;"

Write-Host "\nMigrations V23 and V24 applied successfully." -ForegroundColor Green
Write-Host "If you need a DB-only demo flow SQL, ask and I'll provide the step-by-step commands to exercise the feature." -ForegroundColor Cyan

exit 0
