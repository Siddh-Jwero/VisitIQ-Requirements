param(
    [switch]$Yes,
    [switch]$Venv,
    [string]$Requirements = "https://raw.githubusercontent.com/Siddh-Jwero/VisitIQ-Requirements/main/requirements.txt"
)

function Write-Info($msg) { Write-Host "   $msg" -ForegroundColor Cyan }
function Write-Log($msg)  { Write-Host "==> $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Warning $msg }
function CmdExists($name) { return (Get-Command $name -ErrorAction SilentlyContinue) -ne $null }

Write-Log "Windows installer (PowerShell)"
Write-Info "Requirements source: $Requirements"

if (-not (CmdExists python)) {
    Write-Info "Python not found. Attempting to install..."

    $installed = $false
    if (CmdExists winget) {
        Write-Info "Trying winget (may prompt for elevation)..."
        try {
            winget install --id Python.Python.3 -e --accept-package-agreements --accept-source-agreements -h | Out-Null
            $installed = $true
        } catch {
            Write-Warn "winget install failed or requires manual approval"
        }
    }

    if (-not $installed -and CmdExists choco) {
        Write-Info "Trying Chocolatey..."
        try { choco install -y python | Out-Null; $installed = $true } catch { Write-Warn "choco failed" }
    }

    if (-not $installed -and CmdExists scoop) {
        Write-Info "Trying Scoop..."
        try { scoop install python | Out-Null; $installed = $true } catch { Write-Warn "scoop failed" }
    }

    if (-not $installed) {
        Write-Warn "No package manager available or installation failed. Please install Python from https://www.python.org/downloads/ and ensure 'python' is in PATH."
        exit 1
    }
}

# Refresh function lookups
if (CmdExists python) {
    Write-Info "Found python: $(python --version 2>&1)"
} else {
    Write-Warn "python still not available after install. Open a new shell or add python to PATH."
    exit 1
}

# Download requirements
$tmp = [System.IO.Path]::GetTempFileName()
try {
    Write-Info "Downloading requirements to $tmp"
    Invoke-WebRequest -Uri $Requirements -OutFile $tmp -UseBasicParsing -ErrorAction Stop
} catch {
    Write-Warn "Failed to download requirements: $_"
    exit 1
}

# If requirements contain git+ entries, ensure git is available
$needsGit = Select-String -Path $tmp -Pattern '^git\+|git://' -Quiet
if ($needsGit -and -not (CmdExists git)) {
    Write-Info "Requirements include git repos. Git not found — attempting to install Git..."
    $gitInstalled = $false
    if (CmdExists winget) {
        try { winget install --id Git.Git -e --accept-package-agreements --accept-source-agreements -h | Out-Null; $gitInstalled = $true } catch { }
    }
    if (-not $gitInstalled -and CmdExists choco) {
        try { choco install -y git | Out-Null; $gitInstalled = $true } catch { }
    }
    if (-not $gitInstalled -and CmdExists scoop) {
        try { scoop install git | Out-Null; $gitInstalled = $true } catch { }
    }
    if (-not $gitInstalled) {
        Write-Warn "Git not installed. Please install Git for Windows so pip can fetch git repos."
    } else {
        Write-Info "Git installed or already present"
    }
}

# Install into venv or user site
if ($Venv) {
    Write-Info "Creating virtualenv in .venv"
    & python -m venv .venv
    $pythonExe = Join-Path -Path (Join-Path (Get-Location) '.venv\Scripts') -ChildPath 'python.exe'
    if (-not (Test-Path $pythonExe)) { Write-Warn "Virtualenv python not found at $pythonExe"; exit 1 }
    Write-Info "Installing packages into .venv using $pythonExe"
    & $pythonExe -m pip install --upgrade pip
    & $pythonExe -m pip install -r $tmp
} else {
    Write-Info "Installing packages to user site (python -m pip install --user)"
    & python -m pip install --user --upgrade pip
    & python -m pip install --user -r $tmp
}

Write-Log "Done"
Write-Info "If you created .venv, activate with: .\.venv\Scripts\activate"
Remove-Item $tmp -ErrorAction SilentlyContinue
