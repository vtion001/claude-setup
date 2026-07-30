<#
.SYNOPSIS
    Imports this Claude Code setup onto a new Windows machine.

.DESCRIPTION
    Restores settings, skills, commands, hooks, scripts, global preferences and the
    Windows Terminal background. Rewrites the exporting machine's hardcoded user
    paths to this machine's profile. Backs up anything it replaces.

.PARAMETER DryRun
    Show what would change without writing anything.

.PARAMETER SkipTerminal
    Do not touch Windows Terminal settings.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\install.ps1 -DryRun
    powershell -ExecutionPolicy Bypass -File .\install.ps1
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$SkipTerminal
)

$ErrorActionPreference = 'Stop'
$Root      = Split-Path -Parent $MyInvocation.MyCommand.Path
$ClaudeDir = Join-Path $env:USERPROFILE '.claude'
$Stamp     = Get-Date -Format 'yyyyMMdd-HHmmss'

# The user profile name this bundle was exported from. All hardcoded paths
# referencing it get rewritten to the current machine's profile.
$SourceUser = 'VJ_Rodriguguez'
$TargetUser = Split-Path -Leaf $env:USERPROFILE

# Windows PowerShell 5.1's `Set-Content -Encoding UTF8` emits a BOM, and Node's
# JSON.parse - which Claude Code uses to read settings.json and ~/.claude.json -
# rejects a leading BOM. Always write UTF-8 without one.
function Write-Utf8NoBom {
    param([string]$Path, [string]$Text)
    [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding $false))
}

function Say  ($m) { Write-Host "  $m" }
function Step ($m) { Write-Host "`n==> $m" -ForegroundColor Cyan }
function Warn ($m) { Write-Host "  ! $m" -ForegroundColor Yellow }
function Ok   ($m) { Write-Host "  + $m" -ForegroundColor Green }

if ($DryRun) { Write-Host "DRY RUN - no changes will be written" -ForegroundColor Magenta }
Say "Source profile : $SourceUser"
Say "Target profile : $TargetUser"
Say "Install target : $ClaudeDir"

# ---------------------------------------------------------------- 1. backup
Step "Backing up existing configuration"
if (Test-Path $ClaudeDir) {
    $backup = Join-Path $env:USERPROFILE ".claude-backup-$Stamp"
    if (-not $DryRun) {
        # Copy only config-ish things; skip the huge regenerable caches.
        New-Item -ItemType Directory -Path $backup -Force | Out-Null
        Get-ChildItem $ClaudeDir -Force |
            Where-Object { $_.Name -notin @('plugins','downloads','node_modules','projects','file-history','shell-snapshots','image-cache','cache') } |
            ForEach-Object { Copy-Item $_.FullName -Destination $backup -Recurse -Force -ErrorAction SilentlyContinue }
    }
    Ok "Backed up to $backup"
} else {
    Say "No existing .claude - fresh install"
    if (-not $DryRun) { New-Item -ItemType Directory -Path $ClaudeDir -Force | Out-Null }
}

# ------------------------------------------------------- 2. copy config tree
Step "Installing configuration, skills, commands and hooks"
$payload = Join-Path $Root 'claude'
if (-not (Test-Path $payload)) { throw "Bundle is missing its 'claude' directory: $payload" }

Get-ChildItem $payload -Force | ForEach-Object {
    $dest = Join-Path $ClaudeDir $_.Name
    if (-not $DryRun) { Copy-Item $_.FullName -Destination $dest -Recurse -Force }
    Say "$($_.Name)"
}
Ok "Configuration installed"

# ------------------------------------------------------- 3. rewrite paths
# The bundle carries absolute paths from the exporting machine in several
# encodings: C:/Users/X, C:\Users\X, C:\\Users\\X (JSON-escaped) and //c/Users/X.
Step "Rewriting hardcoded paths to this machine"
if ($SourceUser -eq $TargetUser) {
    Say "Same profile name - no rewrite needed"
} else {
    $targets = Get-ChildItem $ClaudeDir -Recurse -File -Include *.json,*.md,*.ps1,*.sh,*.mjs,*.js,*.py -ErrorAction SilentlyContinue
    $changed = 0
    foreach ($f in $targets) {
        $text = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
        if ($null -eq $text -or $text -notmatch [regex]::Escape($SourceUser)) { continue }
        $new = $text -replace [regex]::Escape($SourceUser), $TargetUser
        if ($new -ne $text) {
            if (-not $DryRun) { Write-Utf8NoBom -Path $f.FullName -Text $new }
            $changed++
        }
    }
    Ok "Rewrote paths in $changed file(s)"
}

# --------------------------------------------------- 4. merge global prefs
Step "Merging global preferences into ~/.claude.json"
# Read from the bundle, not the install target, so this step is independent
# of step 2 having completed (and so -DryRun reports accurately).
$prefsFile  = Join-Path $payload 'global-prefs.json'
$globalJson = Join-Path $env:USERPROFILE '.claude.json'

if (-not (Test-Path $prefsFile)) {
    Warn "global-prefs.json not found - skipping"
} else {
    # This step must never abort the install: the config tree is already in place.
    try {
        $prefs = Get-Content $prefsFile -Raw | ConvertFrom-Json

        if (-not (Test-Path $globalJson)) {
            # Fresh machine - just write the preferences out.
            if (-not $DryRun) { Write-Utf8NoBom -Path $globalJson -Text ($prefs | ConvertTo-Json -Depth 100) }
            foreach ($p in $prefs.PSObject.Properties) { Say "$($p.Name) = $($p.Value)" }
            Ok "Preferences written to a new ~/.claude.json"
        }
        else {
            if (-not $DryRun) { Copy-Item $globalJson "$globalJson.backup-$Stamp" -Force }
            $raw = Get-Content $globalJson -Raw

            # Windows PowerShell's ConvertFrom-Json is case-INsensitive on keys and
            # throws on entries differing only in case (real-world project paths do).
            # Node's JSON.parse - what Claude Code uses - is case-sensitive and
            # last-wins, so the file is valid even when PowerShell cannot parse it.
            $parsed = $null
            try { $parsed = $raw | ConvertFrom-Json } catch { $parsed = $null }

            if ($null -ne $parsed) {
                # Clean path: structured merge, identity/auth keys untouched.
                foreach ($p in $prefs.PSObject.Properties) {
                    $parsed | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value -Force
                    Say "$($p.Name) = $($p.Value)"
                }
                if (-not $DryRun) { Write-Utf8NoBom -Path $globalJson -Text ($parsed | ConvertTo-Json -Depth 100) }
                Ok "Preferences merged (login/identity left untouched)"
            }
            else {
                # Fallback: append before the final brace. Original bytes are left
                # byte-for-byte intact - important for a file holding oauthAccount -
                # and last-wins means these values take effect.
                Warn "Duplicate-case keys present; using append merge (file left intact)"
                $pairs = foreach ($p in $prefs.PSObject.Properties) {
                    Say "$($p.Name) = $($p.Value)"
                    $v = if ($p.Value -is [bool]) { $p.Value.ToString().ToLower() }
                         elseif ($p.Value -is [string]) { '"' + $p.Value + '"' }
                         else { $p.Value }
                    '  "{0}": {1}' -f $p.Name, $v
                }
                $idx = $raw.LastIndexOf('}')
                if ($idx -lt 0) { throw "Malformed ~/.claude.json - no closing brace" }
                $head = $raw.Substring(0, $idx).TrimEnd()
                $head = $head.TrimEnd(',')
                $new  = $head + ",`n" + ($pairs -join ",`n") + "`n}"
                if (-not $DryRun) { Write-Utf8NoBom -Path $globalJson -Text $new }
                Ok "Preferences appended (Claude reads last-wins)"
            }
        }
    }
    catch {
        Warn "Could not merge preferences: $($_.Exception.Message)"
        Warn "Apply claude/global-prefs.json manually - the rest of the install is fine"
    }
}

# ------------------------------------------------- 5. terminal appearance
if (-not $SkipTerminal) {
    Step "Applying Windows Terminal background"
    $bgSrc = Join-Path $Root 'terminal\v-claude-bg-terminal.png'
    $bgDst = Join-Path $ClaudeDir 'v-claude-bg-terminal.png'
    if (Test-Path $bgSrc) {
        if (-not $DryRun) { Copy-Item $bgSrc $bgDst -Force }
        Say "Background image -> $bgDst"
    }

    $wtDir = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState'
    $wtCfg = Join-Path $wtDir 'settings.json'
    $appSrc = Join-Path $Root 'terminal\windows-terminal-appearance.json'

    if ((Test-Path $wtCfg) -and (Test-Path $appSrc)) {
        if (-not $DryRun) { Copy-Item $wtCfg "$wtCfg.backup-$Stamp" -Force }

        # Windows Terminal settings.json is JSONC - strip // comments before parsing.
        $rawWt = (Get-Content $wtCfg -Raw) -replace '(?m)^\s*//.*$',''
        $wt    = $rawWt | ConvertFrom-Json
        $app   = Get-Content $appSrc -Raw | ConvertFrom-Json

        if (-not $wt.profiles)          { $wt | Add-Member profiles ([pscustomobject]@{}) -Force }
        if (-not $wt.profiles.defaults) { $wt.profiles | Add-Member defaults ([pscustomobject]@{}) -Force }

        foreach ($p in $app.profiles.defaults.PSObject.Properties) {
            $val = $p.Value
            # Point the background at THIS machine's copy.
            if ($p.Name -eq 'backgroundImage') { $val = $bgDst -replace '\\','/' }
            $wt.profiles.defaults | Add-Member -NotePropertyName $p.Name -NotePropertyValue $val -Force
            Say "$($p.Name) = $val"
        }
        # Pane bindings (sidebar, split, focus, zoom). Windows Terminal keeps the
        # command in `actions` and the key in `keybindings`, joined by id - so
        # both arrays have to be merged or the sidebar has no shortcut.
        $sidebarDst = (Join-Path $ClaudeDir 'sidebar.ps1') -replace '\\','/'
        if ($app.actions) {
            if (-not $wt.actions) { $wt | Add-Member actions @() -Force }
            $have = @($wt.actions | ForEach-Object { $_.id })
            foreach ($a in $app.actions) {
                # retarget the sidebar script at this machine's copy
                if ($a.command.commandline -and $a.command.commandline -match 'sidebar\.ps1') {
                    $a.command.commandline = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File $sidebarDst"
                }
                if ($have -notcontains $a.id) { $wt.actions = @($wt.actions) + $a; Say "action $($a.id)" }
            }
        }
        if ($app.keybindings) {
            if (-not $wt.keybindings) { $wt | Add-Member keybindings @() -Force }
            foreach ($k in $app.keybindings) {
                # upsert by keystroke so re-running the installer is idempotent
                $wt.keybindings = @($wt.keybindings | Where-Object { $_.keys -ne $k.keys }) + $k
                Say "$($k.keys) -> $($k.id)"
            }
        }

        if (-not $DryRun) { Write-Utf8NoBom -Path $wtCfg -Text ($wt | ConvertTo-Json -Depth 100) }
        Ok "Windows Terminal updated (restart it to see the background)"
    } else {
        Warn "Windows Terminal settings not found - apply terminal/ manually"
    }
}

# -------------------------------------------------------------- 6. secrets
Step "Secrets"
$envExample = Join-Path $Root '.env.example'
$envLocal   = Join-Path $ClaudeDir '.env'
if ((Test-Path $envExample) -and -not (Test-Path $envLocal)) {
    if (-not $DryRun) { Copy-Item $envExample $envLocal -Force }
    Warn "Created $envLocal - fill in your real tokens (they were NOT exported)"
}

# --------------------------------------------------------------- 7. done
Step "Done"
Say "Next steps:"
Say "  1. Run 'claude' - the 74 plugins in settings.json reinstall automatically"
Say "  2. Run '/login' to authenticate (credentials are never exported)"
Say "  3. Fill in $envLocal with your real tokens"
Say "  4. Restart Windows Terminal to pick up the background"
if ($DryRun) { Write-Host "`nDRY RUN complete - nothing was written" -ForegroundColor Magenta }
