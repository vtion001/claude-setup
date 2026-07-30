# prompt-boost - stands in for $VISUAL so ctrl+g rewrites the draft prompt
# instead of opening an editor. Claude Code writes the input buffer to a temp
# file, runs this, then reloads the file back into the prompt box.
#
#   <text>        ctrl+g  ->  AI rewrite (fast path, no project-local CLAUDE.md)
#   +<text>       ctrl+g  ->  AI rewrite with project context (slower, sharper)
#   /cmd  #note   ctrl+g  ->  left untouched (slash command anywhere in buffer)
#   [Image #1]    ctrl+g  ->  left untouched (any attachment placeholder)
#   <empty>       ctrl+g  ->  no-op
#
# ctrl+g NEVER opens an editor. The only editor hand-off left is the git guard
# below, which ctrl+g cannot reach (Claude Code's temp file is never named
# COMMIT_EDITMSG, and Claude Code pins GIT_EDITOR for its own shells).
#
# Original text is kept at ~/.claude/prompt-boost.last.txt
# Every invocation appends one line to ~/.claude/prompt-boost.log

param([Parameter(Position = 0)][string]$File)

[Console]::OutputEncoding = [Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'

$ClaudeExe   = 'D:\npm-global\claude.cmd'
$Model       = 'claude-haiku-4-5-20251001'
$RealEditor  = if ($env:CLAUDE_REAL_EDITOR) { $env:CLAUDE_REAL_EDITOR } else { 'notepad' }
$Home_       = $HOME
$SysPrompt   = Join-Path $Home_ '.claude\prompt-boost.system.md'
$McpConfig   = Join-Path $Home_ '.claude\prompt-boost.mcp.json'
$Backup      = Join-Path $Home_ '.claude\prompt-boost.last.txt'
$Scratch     = Join-Path $env:TEMP 'cc-prompt-boost'

$ESC = [char]27
function Say { param($t, [int]$n = 244) [Console]::Write("$ESC[38;5;${n}m$t$ESC[0m") }
function Line { param($t, [int]$n = 244) [Console]::WriteLine("$ESC[38;5;${n}m$t$ESC[0m") }

# One line per invocation, so "why did it do that?" is always answerable.
$LogFile = Join-Path $HOME '.claude\prompt-boost.log'
function Log {
    param($msg)
    "$(Get-Date -Format 'HH:mm:ss')  $msg" | Add-Content -Path $LogFile -Encoding UTF8
}

if (-not $File -or -not (Test-Path $File)) { exit 0 }
if (-not (Test-Path $ClaudeExe)) { $ClaudeExe = 'claude' }
if (-not (Test-Path $Scratch)) { New-Item -ItemType Directory -Path $Scratch -Force | Out-Null }

# git and friends also honour $VISUAL. If we were handed a commit message,
# rebase todo, tag message etc, hand straight over to a real editor - rewriting
# one of those would be destructive.
$leaf = Split-Path $File -Leaf
if ($leaf -match '^(COMMIT_EDITMSG|MERGE_MSG|SQUASH_MSG|TAG_EDITMSG|NOTES_EDITMSG|git-rebase-todo|addp-hunk-edit\.diff)$') {
    Log "git file '$leaf' -> handing to $RealEditor"
    & cmd /c "$RealEditor `"$File`""
    exit 0
}

$orig = [IO.File]::ReadAllText($File)
$trim = $orig.Trim()

# ctrl+g must never open an editor. Nothing to rewrite -> leave the buffer
# exactly as it is and return immediately.
if ($trim.Length -eq 0) {
    Log 'empty buffer - no-op'
    exit 0
}

# Things that must never be rewritten, checked anywhere in the buffer:
#
#  1. Attachment placeholders. Claude Code substitutes the real image/paste
#     content for these on submit, so a rewrite that reworded or dropped one
#     would silently detach the file. Pattern lifted from Claude Code itself.
#  2. Slash commands (/skills, /code-review ...). The headless subprocess
#     rejects them outright, and a reworded command name stops resolving.
#  3. '#' memory writes - literal control input.
#
# The slash pattern requires start-of-buffer or whitespace before the '/' and a
# letter after it, so "src/App.tsx", "and/or" and "100/50" are NOT caught.
$attachRe = '\[(?:Pasted text #\d+(?: \+\d+ lines)?|Image #\d+|Audio #\d+|Image|Image source:[^\]]*|Image:[^\]]*|\.\.\.Truncated text #\d+[^\]]*)\]'
$slashRe  = '(?:^|\s)/[a-zA-Z][\w-]*'

$skip = $null
if ($trim -match $attachRe)      { $skip = "attachment $($Matches[0])" }
elseif ($trim -match $slashRe)   { $skip = "slash command $($Matches[0].Trim())" }
elseif ($trim.StartsWith('#'))   { $skip = 'memory write' }

if ($skip) {
    Log "skip ($skip) - buffer untouched"
    Say "$([char]0x2570)$([char]0x2500) " 240
    Line "$skip - left untouched" 244
    Start-Sleep -Milliseconds 900
    exit 0
}

# --- mode -------------------------------------------------------------------
$withContext = $trim.StartsWith('+')
if ($withContext) { $trim = $trim.Substring(1).TrimStart() }
if ($trim.Length -eq 0) { exit 0 }

[IO.File]::WriteAllText($Backup, $orig)

Line ''
Say "$([char]0x256D)$([char]0x2500) " 240
Say 'PROMPT BOOST ' 45
Say "$Model " 111
if ($withContext) { Say '+context ' 213 }
Line "$($trim.Length) chars" 244

# --- build the call ---------------------------------------------------------
$cliArgs = @(
    '-p'
    '--model', $Model
    '--system-prompt-file', "`"$SysPrompt`""
    '--setting-sources', 'project'
    '--strict-mcp-config'
    '--mcp-config', "`"$McpConfig`""
    '--disable-slash-commands'
    '--allowed-tools', '""'
) -join ' '

$psi = New-Object Diagnostics.ProcessStartInfo
$psi.FileName               = $ClaudeExe
$psi.Arguments              = $cliArgs
$psi.WorkingDirectory       = if ($withContext) { (Get-Location).Path } else { $Scratch }
$psi.UseShellExecute        = $false
$psi.CreateNoWindow         = $true
$psi.RedirectStandardInput  = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError  = $true
# Extended thinking is the single biggest cost here: Haiku burned ~1400 thinking
# tokens (13-26s) on a rewrite that needs ~50. The few-shot examples in the
# system prompt carry the instruction-following that thinking was providing.
$psi.EnvironmentVariables['MAX_THINKING_TOKENS'] = '0'
$psi.EnvironmentVariables['DISABLE_INTERLEAVED_THINKING'] = '1'

$sw = [Diagnostics.Stopwatch]::StartNew()
$proc = [Diagnostics.Process]::Start($psi)
$proc.StandardInput.Write($trim)
$proc.StandardInput.Close()
$outTask = $proc.StandardOutput.ReadToEndAsync()
$errTask = $proc.StandardError.ReadToEndAsync()

$frames = @('|', '/', '-', '\')
$i = 0
while (-not $proc.HasExited) {
    Say "`r$([char]0x2570)$([char]0x2500) $($frames[$i % 4]) synthesising  $('{0:N1}s' -f $sw.Elapsed.TotalSeconds)   " 240
    $i++
    Start-Sleep -Milliseconds 110
}
$proc.WaitForExit()
$sw.Stop()

$out = $outTask.Result
$err = $errTask.Result

# --- write back -------------------------------------------------------------
$clean = $out.Trim()
if ($clean -match '^```[a-zA-Z]*\r?\n([\s\S]*?)\r?\n```$') { $clean = $Matches[1].Trim() }

[Console]::Write("`r$ESC[2K")
if ($proc.ExitCode -ne 0 -or $clean.Length -eq 0) {
    Say "$([char]0x2570)$([char]0x2500) " 240
    Line "boost failed (exit $($proc.ExitCode)) - prompt left untouched" 203
    if ($err) { Line ("   " + ($err.Trim() -split "`n")[0]) 240 }
    Start-Sleep -Milliseconds 1400
    exit 0
}

[IO.File]::WriteAllText($File, $clean)
Say "$([char]0x2570)$([char]0x2500) " 240
Say "$([char]0x2713) " 78
Line "$('{0:N1}s' -f $sw.Elapsed.TotalSeconds)  $($trim.Length) $([char]0x2192) $($clean.Length) chars   (original saved to ~/.claude/prompt-boost.last.txt)" 244
Start-Sleep -Milliseconds 550
exit 0
