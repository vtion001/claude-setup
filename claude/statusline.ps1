# Claude Code mission-control status line.
# Reads the statusLine JSON payload on stdin, prints 3 ANSI-coloured rows.
# Every value shown is real telemetry from the session or the machine.

[Console]::OutputEncoding = [Text.Encoding]::UTF8
$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference    = 'SilentlyContinue'

# Set to $false if any glyph renders as a tofu box (needs a Nerd Font).
$NERD = $true

$raw = [Console]::In.ReadToEnd()
if (Test-Path "$HOME\.claude\statusline.debug") {
    # WriteAllText, not Set-Content: PS 5.1 would prepend a BOM and the dump
    # would then no longer parse the way Claude Code's real stdin does.
    [IO.File]::WriteAllText("$HOME\.claude\statusline.last.json", $raw)
}
$d = $raw | ConvertFrom-Json
if (-not $d) { exit 0 }

$ESC = [char]27
function C  { param($t, [int]$n) "$ESC[38;5;${n}m$t$ESC[0m" }
function Dim { param($t) "$ESC[2m$t$ESC[0m" }

# --- glyphs -----------------------------------------------------------------
if ($NERD) {
    $gBranch = [char]0xE0A0    #
    $gPr     = [char]0xF407    #
} else {
    $gBranch = '@'
    $gPr     = 'PR'
}

# --- helpers ----------------------------------------------------------------
function Bar {
    param([double]$pct, [int]$w, [string]$full, [string]$empty)
    $f = [int][Math]::Round(($pct / 100.0) * $w)
    if ($f -gt $w) { $f = $w }; if ($f -lt 0) { $f = 0 }
    ($full * $f) + ($empty * ($w - $f))
}
# green under 60%, amber under 85%, red above
function TCol { param([double]$p) if ($p -lt 60) { 78 } elseif ($p -lt 85) { 214 } else { 203 } }

function Kfmt {
    param([double]$n)
    if ($n -ge 1000000) { '{0:N1}M' -f ($n / 1000000) }
    elseif ($n -ge 1000) { '{0:N0}k' -f ($n / 1000) }
    else { '{0:N0}' -f $n }
}

function Dfmt {
    param([double]$ms)
    $s = [int]($ms / 1000)
    if ($s -ge 3600) { '{0}h{1:00}m' -f [int]($s / 3600), [int](($s % 3600) / 60) }
    elseif ($s -ge 60) { '{0}m' -f [int]($s / 60) }
    else { "${s}s" }
}

# --- machine metrics, cached 5s so the refresh tick stays cheap -------------
$sysCache = Join-Path $env:TEMP 'cc-statusline-sys.json'
$sys = $null
if (Test-Path $sysCache) {
    $age = (Get-Date) - (Get-Item $sysCache).LastWriteTime
    if ($age.TotalSeconds -lt 5) { $sys = Get-Content $sysCache -Raw | ConvertFrom-Json }
}
if (-not $sys) {
    $cpu = (Get-CimInstance Win32_Processor -Property LoadPercentage |
            Measure-Object -Property LoadPercentage -Average).Average
    $os  = Get-CimInstance Win32_OperatingSystem -Property FreePhysicalMemory, TotalVisibleMemorySize
    $totGb  = [Math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
    $usedGb = [Math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1MB, 1)
    $sys = [pscustomobject]@{ cpu = [int]$cpu; usedGb = $usedGb; totGb = $totGb }
    $sys | ConvertTo-Json -Compress | Set-Content $sysCache -Encoding UTF8
}

# ============================================================================
# ROW 1 — identity / model / mode
# ============================================================================
$r1 = @()
$r1 += C "$($env:USERNAME)@$($env:COMPUTERNAME)" 45
if ($d.model.display_name) { $r1 += C $d.model.display_name 111 }
if ($d.effort.level)       { $r1 += C "effort:$($d.effort.level.ToUpper())" 140 }
if ($d.fast_mode)                    { $r1 += C 'FAST' 220 }
if ($d.thinking -and -not $d.thinking.enabled) { $r1 += Dim 'think:off' }
if ($d.agent.name)         { $r1 += C "agent:$($d.agent.name)" 213 }
if ($d.remote.session_id)  { $r1 += C 'REMOTE' 51 }
if ($d.vim.mode -and $d.vim.mode -ne 'INSERT') { $r1 += C $d.vim.mode 220 }
if ($d.output_style.name -and $d.output_style.name -ne 'default') {
    $r1 += Dim $d.output_style.name
}
$r1 += C (Get-Date -Format 'HH:mm:ss') 244

# ============================================================================
# ROW 2 — session telemetry
# ============================================================================
$r2 = @()
$cw = $d.context_window
if ($cw -and $cw.context_window_size) {
    $p   = [double]$cw.used_percentage
    $col = TCol $p
    $r2 += "$(C 'CTX' 244) $(C (Bar $p 10 ([char]0x2588) ([char]0x2591)) $col) $(C ('{0:N0}%' -f $p) $col) $(Dim "$(Kfmt $cw.total_input_tokens)/$(Kfmt $cw.context_window_size)")"
}
if ($d.exceeds_200k_tokens) { $r2 += C 'OVER-200k' 203 }

$cost = $d.cost
if ($cost) {
    $r2 += C ('${0:N2}' -f [double]$cost.total_cost_usd) 108
    if ($cost.total_duration_ms -gt 0) { $r2 += Dim (Dfmt $cost.total_duration_ms) }
}

$rl = $d.rate_limits
if ($rl.five_hour) {
    $p = [double]$rl.five_hour.used_percentage
    $r2 += "$(Dim '5h') $(C (Bar $p 5 ([char]0x2593) ([char]0x2591)) (TCol $p)) $(C ('{0:N0}%' -f $p) (TCol $p))"
}
if ($rl.seven_day) {
    $p = [double]$rl.seven_day.used_percentage
    $r2 += "$(Dim '7d') $(C (Bar $p 5 ([char]0x2593) ([char]0x2591)) (TCol $p)) $(C ('{0:N0}%' -f $p) (TCol $p))"
}

# ============================================================================
# ROW 3 — repo / PR / machine
# ============================================================================
$r3 = @()
$dir = $d.workspace.current_dir
if (-not $dir) { $dir = $d.cwd }

$branch = $null; $ahead = 0; $behind = 0; $dirty = 0
if ($dir -and (Test-Path $dir)) {
    Push-Location $dir
    $gs = & git status --porcelain=v2 --branch --untracked-files=no 2>$null
    Pop-Location
    foreach ($line in $gs) {
        if ($line -like '# branch.head *') { $branch = $line.Substring(14) }
        elseif ($line -like '# branch.ab *') {
            if ($line -match '\+(\d+)\s+-(\d+)') { $ahead = [int]$Matches[1]; $behind = [int]$Matches[2] }
        }
        elseif ($line -match '^[12u] ') { $dirty++ }
    }
}

# workspace.repo is an object {host, owner, name} - not a string
$repo = $d.workspace.repo.name
if (-not $repo -and $d.workspace.project_dir) { $repo = Split-Path $d.workspace.project_dir -Leaf }
if ($repo) { $r3 += C $repo 117 } elseif ($dir) { $r3 += Dim (Split-Path $dir -Leaf) }

if ($branch) {
    $seg = C "$gBranch $branch" 150
    if ($ahead)  { $seg += ' ' + (C "$([char]0x2191)$ahead" 220) }
    if ($behind) { $seg += ' ' + (C "$([char]0x2193)$behind" 220) }
    if ($dirty)  { $seg += ' ' + (C "$([char]0x25CF)$dirty" 203) }
    $r3 += $seg
}
if ($d.workspace.git_worktree -or $d.worktree) {
    $wt = $d.worktree.name; if (-not $wt) { $wt = 'worktree' }
    $r3 += C "wt:$wt" 213
}

if ($d.cost -and ($d.cost.total_lines_added -or $d.cost.total_lines_removed)) {
    $r3 += "$(C "$([char]0x271A)$($d.cost.total_lines_added)" 78) $(C "$([char]0x2716)$($d.cost.total_lines_removed)" 203)"
}

if ($d.pr.number) {
    $seg = C "$gPr #$($d.pr.number)" 111
    switch ($d.pr.review_state) {
        'approved'          { $seg += ' ' + (C "$([char]0x2713)approved" 78) }
        'changes_requested' { $seg += ' ' + (C "$([char]0x2717)changes" 203) }
        default             { if ($d.pr.review_state) { $seg += ' ' + (Dim $d.pr.review_state) } }
    }
    $r3 += $seg
}

$r3 += "$(Dim 'CPU') $(C "$($sys.cpu)%" (TCol $sys.cpu))"
$memPct = if ($sys.totGb) { ($sys.usedGb / $sys.totGb) * 100 } else { 0 }
$r3 += "$(Dim 'MEM') $(C "$($sys.usedGb)/$($sys.totGb)G" (TCol $memPct))"

# ============================================================================
$sep  = Dim ' | '
$rule = "$ESC[38;5;240m"
$out  = @(
    "$rule$([char]0x256D)$([char]0x2500) $ESC[0m$($r1 -join (Dim ' - '))"
    "$rule$([char]0x251C)$([char]0x2500) $ESC[0m$($r2 -join $sep)"
    "$rule$([char]0x2570)$([char]0x2500) $ESC[0m$($r3 -join $sep)"
) -join "`n"
[Console]::Out.Write($out)
