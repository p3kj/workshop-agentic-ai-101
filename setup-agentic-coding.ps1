#Requires -Version 5.1
<#
.SYNOPSIS
    Agentic Coding Workshop - Prerequisites Installer
.DESCRIPTION
    Installs and/or updates: Git, Node.js LTS, Windows Terminal, VS Code, Python.
    Safe to re-run — skips what is already present, offers to update outdated packages.
    Uses winget (App Installer) which ships with Windows 10 22H2+ and Windows 11.
.NOTES
    Double-click or right-click → "Run with PowerShell".
    The script will request admin rights automatically (UAC prompt).
    After the script finishes, CLOSE and REOPEN your terminal so PATH changes take effect.
#>

# ── Self-elevate to Administrator ───────────────────────────────────────────
$isAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    # Re-launch this same script as Administrator; -Verb RunAs triggers the UAC prompt
    $argList = "-ExecutionPolicy Bypass -File `"$PSCommandPath`""
    try {
        Start-Process powershell -Verb RunAs -ArgumentList $argList
    }
    catch {
        Write-Host "  Could not get admin rights. Right-click PowerShell → 'Run as administrator' and try again." -ForegroundColor Red
        Read-Host "Press Enter to exit"
    }
    exit
}

# ── Colour helpers ──────────────────────────────────────────────────────────
function Write-Step   { param([string]$msg) Write-Host "`n▶ $msg"   -ForegroundColor Cyan    }
function Write-Ok     { param([string]$msg) Write-Host "  ✓ $msg"   -ForegroundColor Green   }
function Write-Skip   { param([string]$msg) Write-Host "  • $msg"   -ForegroundColor DarkGray}
function Write-Warn   { param([string]$msg) Write-Host "  ⚠ $msg"   -ForegroundColor Yellow  }
function Write-Err    { param([string]$msg) Write-Host "  ✗ $msg"   -ForegroundColor Red     }

# ── Winget availability ─────────────────────────────────────────────────────
Write-Step "Checking winget (Windows Package Manager)"

$wingetCmd = Get-Command winget -ErrorAction SilentlyContinue
if (-not $wingetCmd) {
    Write-Err "winget not found."
    Write-Host "    Install 'App Installer' from the Microsoft Store, then re-run." -ForegroundColor Yellow
    Write-Host "    https://aka.ms/getwinget" -ForegroundColor Yellow
    Read-Host  "Press Enter to exit"
    exit 1
}

# Capture winget version for the log
$wingetVersion = (winget --version 2>$null) -replace '[^0-9.]', ''
Write-Ok "winget $wingetVersion found"

# Accept source agreements silently so prompts don't block the script
winget source update --accept-source-agreements 2>$null | Out-Null

# ── Package definitions ─────────────────────────────────────────────────────
# Each entry: WingetId, friendly name, quick-check command, notes
$packages = @(
    @{
        Id       = "Git.Git"
        Name     = "Git for Windows"
        Check    = "git"
        PostMsg  = "Includes Git Bash (used internally by Claude Code)"
    },
    @{
        Id       = "OpenJS.NodeJS.LTS"
        Name     = "Node.js LTS"
        Check    = "node"
        PostMsg  = "Needed for Gemini CLI and npm packages"
    },
    @{
        Id       = "Microsoft.WindowsTerminal"
        Name     = "Windows Terminal"
        Check    = "wt"
        PostMsg  = "Modern terminal with tabs, themes, and split panes"
    },
    @{
        Id       = "Microsoft.VisualStudioCode"
        Name     = "Visual Studio Code"
        Check    = "code"
        PostMsg  = "Code & Markdown editor — install 'Markdown All in One' extension later"
    },
    @{
        Id       = "Python.Python.3.12"
        Name     = "Python 3.12"
        Check    = "python"
        PostMsg  = "Useful for scripting and many AI tools"
    }
)

# ── Helper: check if a command is reachable ─────────────────────────────────
function Test-CommandExists {
    param([string]$cmd)
    $null -ne (Get-Command $cmd -ErrorAction SilentlyContinue)
}

# ── Helper: get installed version via winget ────────────────────────────────
function Get-WingetInstalledVersion {
    param([string]$id)
    # winget list is noisy; grab the matching line
    $line = winget list --id $id --exact --accept-source-agreements 2>$null |
            Select-String $id
    if ($line) {
        # Extract version-looking token (digits and dots)
        if ($line -match '(\d+\.\d+[\.\d]*)') { return $Matches[1] }
    }
    return $null
}

# ── Main install / update loop ──────────────────────────────────────────────
$installed  = @()
$updated    = @()
$skipped    = @()
$failed     = @()

foreach ($pkg in $packages) {
    Write-Step "$($pkg.Name)"

    $existingVersion = Get-WingetInstalledVersion -id $pkg.Id

    if ($existingVersion) {
        Write-Skip "Already installed (v$existingVersion) — checking for updates..."

        $upgradeOutput = winget upgrade --id $pkg.Id --exact `
                         --accept-package-agreements --accept-source-agreements 2>&1

        $upgradeText = $upgradeOutput | Out-String

        if ($upgradeText -match "No applicable update found|No installed package found|is up to date") {
            Write-Ok "Up to date — nothing to do"
            $skipped += $pkg.Name
        }
        else {
            Write-Ok "Updated  → $($pkg.PostMsg)"
            $updated += $pkg.Name
        }
    }
    else {
        Write-Host "  Installing..." -ForegroundColor White -NoNewline

        $installOutput = winget install --id $pkg.Id --exact --silent `
                         --accept-package-agreements --accept-source-agreements 2>&1

        $installText = $installOutput | Out-String

        if ($LASTEXITCODE -ne 0 -and $installText -notmatch "already installed") {
            Write-Err "Installation failed. Try manually:  winget install $($pkg.Id)"
            $failed += $pkg.Name
        }
        else {
            Write-Host ""  # close the -NoNewline
            Write-Ok "Installed → $($pkg.PostMsg)"
            $installed += $pkg.Name
        }
    }
}

# ── Refresh PATH for this session (best-effort) ────────────────────────────
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("Path", "User")

# ── Post-install: configure npm global directory (avoids permission issues) ─
Write-Step "Configuring npm global directory"
if (Test-CommandExists "npm") {
    $npmPrefix = npm config get prefix 2>$null
    Write-Ok "npm prefix: $npmPrefix"
    Write-Skip "To install Gemini CLI later:  npm install -g @google/gemini-cli"
}
else {
    Write-Warn "npm not yet in PATH — restart your terminal first, then configure"
}

# ── Post-install: set Git default branch to 'main' ─────────────────────────
Write-Step "Configuring Git defaults"
if (Test-CommandExists "git") {
    git config --global init.defaultBranch main    2>$null
    git config --global core.autocrlf true         2>$null
    Write-Ok "Default branch: main, line endings: auto-crlf"
}
else {
    Write-Warn "git not yet in PATH — restart your terminal first"
}

# ── Summary ─────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "  SUMMARY" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan

if ($installed.Count -gt 0) {
    Write-Host "  Freshly installed : " -NoNewline -ForegroundColor Green
    Write-Host ($installed -join ", ")
}
if ($updated.Count -gt 0) {
    Write-Host "  Updated           : " -NoNewline -ForegroundColor Yellow
    Write-Host ($updated -join ", ")
}
if ($skipped.Count -gt 0) {
    Write-Host "  Already up to date: " -NoNewline -ForegroundColor DarkGray
    Write-Host ($skipped -join ", ")
}
if ($failed.Count -gt 0) {
    Write-Host "  Failed            : " -NoNewline -ForegroundColor Red
    Write-Host ($failed -join ", ")
}

Write-Host ""
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "  NEXT STEPS" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  1. CLOSE this terminal and OPEN a new one (so PATH updates take effect)" -ForegroundColor White
Write-Host "  2. Verify installations:" -ForegroundColor White
Write-Host "       git --version" -ForegroundColor Gray
Write-Host "       node --version" -ForegroundColor Gray
Write-Host "       python --version" -ForegroundColor Gray
Write-Host "       code --version" -ForegroundColor Gray
Write-Host ""
Write-Host "  3. Install your AI coding tool of choice:" -ForegroundColor White
Write-Host "       Claude Code  →  irm https://claude.ai/install.ps1 | iex" -ForegroundColor Gray
Write-Host "       Gemini CLI   →  npm install -g @google/gemini-cli" -ForegroundColor Gray
Write-Host ""
Write-Host "  4. Recommended VS Code extensions:" -ForegroundColor White
Write-Host "       code --install-extension yzhang.markdown-all-in-one" -ForegroundColor Gray
Write-Host "       code --install-extension esbenp.prettier-vscode" -ForegroundColor Gray
Write-Host ""

Read-Host "Press Enter to close"
