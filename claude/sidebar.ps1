# sidebar - a companion pane for Claude Code.
#
# Claude Code has no file explorer and no arbitrary-file viewer; its only panel
# is hardcoded to git-diff content. This runs in a Windows Terminal pane beside
# it and provides both.
#
#   no target  ->  file tree of the repo Claude Code is working in
#   a target   ->  that file, with line numbers, following edits live
#
# Point it at a file by writing the path to ~/.claude/sidebar.target:
#     echo C:/path/to/file.php > ~/.claude/sidebar.target
# Clear it to go back to the tree:
#     : > ~/.claude/sidebar.target
#
# Root is auto-detected from the newest live Claude Code session, so it follows
# whatever project you are in. Override with -Root.

param(
    [string]$Root,
    [int]$IntervalMs = 800
)

[Console]::OutputEncoding = [Text.Encoding]::UTF8
$ErrorActionPreference = 'SilentlyContinue'

$ESC       = [char]27
$TargetF   = Join-Path $HOME '.claude\sidebar.target'
$MaxFiles  = 400

function C { param($t, [int]$n) "$ESC[38;5;${n}m$t$ESC[0m" }

# Follow whatever project Claude Code is actually in.
#
# Measured at 43ms - by far the most expensive thing in the loop, and it almost
# never changes. The sessions directory's own mtime moves whenever a session
# file is written, so it is a sufficient cache key and costs ~1ms to read.
$script:RootCache = $null
$script:RootStamp = $null
function Resolve-Root {
    if ($Root) { return $Root }
    $dir = Join-Path $HOME '.claude\sessions'
    if (-not (Test-Path $dir)) { return $HOME }
    $stamp = (Get-Item $dir).LastWriteTimeUtc.Ticks
    if ($script:RootCache -and $stamp -eq $script:RootStamp) { return $script:RootCache }

    $r = $HOME
    $s = Get-ChildItem $dir -Filter *.json -File |
         Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($s) {
        $j = Get-Content $s.FullName -Raw | ConvertFrom-Json
        if ($j.cwd -and (Test-Path $j.cwd)) { $r = $j.cwd }
    }
    $script:RootCache = $r
    $script:RootStamp = $stamp
    return $r
}

# git ls-files is both faster than walking the tree and already gitignore-aware,
# which is what keeps node_modules out without maintaining an exclude list.
function Get-Tree {
    param([string]$root, [int]$rows)
    Push-Location $root
    $files = & git ls-files --cached --others --exclude-standard 2>$null
    Pop-Location
    if (-not $files) {
        $files = Get-ChildItem $root -Recurse -File -Depth 2 |
                 ForEach-Object { $_.FullName.Substring($root.Length).TrimStart('\','/') -replace '\\','/' }
    }
    $files = $files | Select-Object -First $MaxFiles

    $byDir = [ordered]@{}
    foreach ($f in $files) {
        $d = if ($f.Contains('/')) { $f.Substring(0, $f.LastIndexOf('/')) } else { '.' }
        if (-not $byDir.Contains($d)) { $byDir[$d] = New-Object Collections.ArrayList }
        [void]$byDir[$d].Add(($f -split '/')[-1])
    }

    $out = New-Object Collections.ArrayList
    foreach ($d in $byDir.Keys) {
        if ($out.Count -ge $rows) { break }
        [void]$out.Add((C "$d/" 111))
        foreach ($n in $byDir[$d]) {
            if ($out.Count -ge $rows) { break }
            [void]$out.Add('  ' + (C $n 250))
        }
    }
    return $out
}

function Get-FileView {
    param([string]$path, [int]$rows)
    $out = New-Object Collections.ArrayList
    $lines = Get-Content -LiteralPath $path -TotalCount ($rows + 1) -ErrorAction SilentlyContinue
    if ($null -eq $lines) { [void]$out.Add((C 'unreadable' 203)); return $out }
    $i = 1
    foreach ($l in $lines) {
        if ($out.Count -ge $rows) { break }
        [void]$out.Add((C ('{0,4} ' -f $i) 240) + ($l -replace "`t", '    '))
        $i++
    }
    return $out
}

# Redraw only when something actually changed - a pane that repaints every tick
# flickers and makes the text unselectable.
$lastKey = ""
$lastBody = ""
$lastHead = ""
while ($true) {
    $root = Resolve-Root
    $target = $null
    if (Test-Path $TargetF) {
        $t = (Get-Content $TargetF -Raw).Trim()
        if ($t -and (Test-Path -LiteralPath $t -PathType Leaf)) { $target = $t }
    }

    $size = $Host.UI.RawUI.WindowSize
    $rows = [Math]::Max(6, $size.Height - 4)

    if ($target) {
        # a file has one authoritative stamp, so the cheap key is exact
        $stamp = (Get-Item -LiteralPath $target).LastWriteTimeUtc.Ticks
        $key   = "f|$target|$stamp|$rows"
        $head  = C (Split-Path $target -Leaf) 45
        $sub   = C (Split-Path $target -Parent) 240
    } else {
        # A directory mtime only moves for top-level changes, and .git/index only
        # for git operations, so neither is sufficient on its own. Rather than
        # force a periodic redraw - which would flicker and break selection - use
        # them to decide when to RECOMPUTE, then redraw only if the rendered text
        # actually differs. git ls-files is 66ms on a 947-file repo, so a 3s
        # recompute floor is affordable and catches untracked edits too.
        $stamp = (Get-Item $root).LastWriteTimeUtc.Ticks
        $idx = Join-Path $root '.git\index'
        if (Test-Path $idx) { $stamp = "$stamp/" + (Get-Item $idx).LastWriteTimeUtc.Ticks }
        $key  = "t|$root|$rows|$stamp|" + [int]([Diagnostics.Stopwatch]::GetTimestamp() /
                                                 ([Diagnostics.Stopwatch]::Frequency * 3))
        $head = C (Split-Path $root -Leaf) 45
        $sub  = C $root 240
    }

    if ($key -ne $lastKey) {
        $lastKey = $key
        $body = if ($target) { Get-FileView $target $rows } else { Get-Tree $root $rows }
        $rendered = ($body -join "`n")
        # content comparison is what actually prevents the repaint; the key above
        # only decides how often we are willing to look
        if ($rendered -ne $lastBody -or $head -ne $lastHead) {
            $lastBody = $rendered
            $lastHead = $head
            Clear-Host
            Write-Output $head
            Write-Output $sub
            Write-Output (C ([string]([char]0x2500) * [Math]::Max(10, $size.Width - 1)) 238)
            $body | ForEach-Object { Write-Output $_ }
        }
    }
    Start-Sleep -Milliseconds $IntervalMs
}
