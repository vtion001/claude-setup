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
function Resolve-Root {
    if ($Root) { return $Root }
    $dir = Join-Path $HOME '.claude\sessions'
    $s = Get-ChildItem $dir -Filter *.json -File |
         Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($s) {
        $j = Get-Content $s.FullName -Raw | ConvertFrom-Json
        if ($j.cwd -and (Test-Path $j.cwd)) { return $j.cwd }
    }
    return $HOME
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
$lastKey = ''
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
        $stamp = (Get-Item -LiteralPath $target).LastWriteTimeUtc.Ticks
        $key   = "f|$target|$stamp|$rows"
        $head  = C (Split-Path $target -Leaf) 45
        $sub   = C (Split-Path $target -Parent) 240
    } else {
        $key  = "t|$root|$rows|" + ((Get-Item $root).LastWriteTimeUtc.Ticks)
        $head = C (Split-Path $root -Leaf) 45
        $sub  = C $root 240
    }
    if ($key -ne $lastKey) {
        $lastKey = $key
        $body = if ($target) { Get-FileView $target $rows } else { Get-Tree $root $rows }
        Clear-Host
        Write-Output $head
        Write-Output $sub
        Write-Output (C ([string]([char]0x2500) * [Math]::Max(10, $size.Width - 1)) 238)
        $body | ForEach-Object { Write-Output $_ }
    }
    Start-Sleep -Milliseconds $IntervalMs
}
