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
# Every rewrite is given the tail of the CONVERSATION the draft was typed into,
# so "fix the second one" resolves instead of coming back untouched. See
# Get-SessionInfo below for how the calling session is identified.
#
# ctrl+g NEVER opens an editor. The only editor hand-off left is the git guard
# below, which ctrl+g cannot reach (Claude Code's temp file is never named
# COMMIT_EDITMSG, and Claude Code pins GIT_EDITOR for its own shells).
#
# Original text is kept at ~/.claude/prompt-boost.last.txt
# Every invocation appends one line to ~/.claude/prompt-boost.log
#
#   -Probe    resolve the session and print the context block, rewrite nothing

param(
    [Parameter(Position = 0)][string]$File,
    [switch]$Probe
)

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

# --- conversation context ----------------------------------------------------
# The draft arrives as a bare temp file - Claude Code tells the editor nothing
# about which session produced it. Two facts make the caller recoverable:
#
#   1. ~/.claude/sessions/<pid>.json maps a live claude pid -> sessionId + cwd
#   2. this script is a descendant of that pid (claude -> cmd -> powershell)
#
# so walking the parent-process chain until a pid has a session file identifies
# the exact conversation. That precision matters: several sessions routinely run
# in the same cwd, and "newest transcript in this directory" picks the wrong one.
# Caps measured against real transcripts, not guessed. Across three live
# sessions: assistant turns run 4.0k-7.9k chars, user turns 37-450, and eight
# real turns total ~25k. So the two roles need different budgets - a single
# number either starves the replies or wastes nothing on the prompts. What the
# user actually typed is the highest-signal text per char and is essentially
# free, so it is never trimmed in practice; the replies are the bulk, and older
# ones get the tighter budget.
#
# Truncation keeps head AND tail (see Get-Trimmed), so an enumerated list at the
# end of a long reply - the thing "the second one" points at - survives.
#
# The per-turn caps are set above the observed maxima on purpose: at these
# values a typical window passes through uncut and the total cap is what
# actually governs, so trimming stops being the reason a reference fails to
# resolve. Worst case is ~45k chars (~11k tokens) of prefill per press.
$CtxMaxTurns  = 12      # user/assistant turns handed to the rewriter
$CtxUserCap   = 3000    # chars kept for a user turn - they run far under this
$CtxRecentCap = 8000    # chars kept for the 2 newest turns - references point here
$CtxOlderCap  = 6000    # chars kept for older replies
$CtxTotalCap  = 45000   # hard ceiling on the block; oldest turns dropped first

function Get-SessionInfo {
    $dir = Join-Path $HOME '.claude\sessions'
    if (-not (Test-Path $dir)) { return $null }
    # one bulk WMI query beats one filtered query per hop (~140ms vs ~600ms)
    $map = @{}
    Get-CimInstance -Query 'SELECT ProcessId,ParentProcessId FROM Win32_Process' |
        ForEach-Object { $map[[int]$_.ProcessId] = [int]$_.ParentProcessId }
    $p = $PID
    for ($i = 0; $i -lt 12 -and $p; $i++) {
        $f = Join-Path $dir "$p.json"
        if (Test-Path $f) { return (Get-Content $f -Raw | ConvertFrom-Json) }
        $p = $map[$p]
    }
    return $null
}

function Get-TranscriptPath {
    param($sess)
    if (-not $sess.sessionId) { return $null }
    $root = Join-Path $HOME '.claude\projects'
    if ($sess.cwd) {
        # Claude Code's project slug: everything but letters, digits and dots
        # becomes '-'  (C:\Users\VJ_Rodriguguez -> C--Users-VJ-Rodriguguez)
        $slug = $sess.cwd -replace '[^A-Za-z0-9.]', '-'
        $p = Join-Path $root "$slug\$($sess.sessionId).jsonl"
        if (Test-Path $p) { return $p }
    }
    $hit = Get-ChildItem -Path $root -Filter "$($sess.sessionId).jsonl" -File -Recurse -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($hit) { return $hit.FullName }
    return $null
}

function Get-MessageText {
    param($msg)
    if (-not $msg) { return $null }
    $c = $msg.content
    if ($c -is [string]) { return $c }
    $parts = @()
    foreach ($b in $c) { if ($b.type -eq 'text' -and $b.text) { $parts += [string]$b.text } }
    if (-not $parts.Count) { return $null }
    return ($parts -join "`n")
}

# Harness-injected text is not something the user said, and feeding it to the
# rewriter is how a system-reminder ends up quoted back inside a prompt.
function Get-CleanUserText {
    param([string]$t)
    $t = [Regex]::Replace($t, '(?s)<system-reminder>.*?</system-reminder>', '')
    $t = [Regex]::Replace($t, '(?s)<command-(name|message|args)>.*?</command-\1>', '')
    $t = [Regex]::Replace($t, '(?s)<local-command-(stdout|stderr)>.*?</local-command-\1>', '')
    $t = $t.Trim()
    if ($t.Length -eq 0 -or $t.StartsWith('<') -or $t.StartsWith('Caveat:')) { return $null }
    return $t
}

function Get-Trimmed {
    param([string]$t, [int]$max)
    $t = ($t -replace '\s+', ' ').Trim()
    if ($t.Length -le $max) { return $t }
    # keep both ends: the setup is usually at the front, the list or the
    # conclusion a reference points at is usually at the back
    $head = [int]($max * 0.6)
    $tail = $max - $head
    return $t.Substring(0, $head).TrimEnd() + ' ... ' + $t.Substring($t.Length - $tail).TrimStart()
}

function Get-RecentTurns {
    param([string]$path)
    # How deep this reads is a second, easily-missed cap on how far back a
    # reference can resolve: measured across the six heaviest transcripts here, a
    # 1MB tail reached only 5-6 turns in a tool-heavy session, 4MB reached 10-13,
    # 8MB reached 12-13 everywhere. It is nearly free because the scan below
    # walks backwards and stops at $CtxMaxTurns - on a 28MB transcript only ~164
    # lines are ever touched, so the cost is the read and split alone (~90-330ms,
    # dominated by whether the file is in the OS cache, not by the size).
    $bytes = 8MB
    $len = 0
    $fs = [IO.File]::Open($path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    try {
        $len = $fs.Length
        if ($len -gt $bytes) { [void]$fs.Seek(-$bytes, [IO.SeekOrigin]::End) }
        $sr = New-Object IO.StreamReader($fs, [Text.Encoding]::UTF8)
        $text = $sr.ReadToEnd()
    } finally { $fs.Dispose() }

    $lines = $text -split "`n"
    if ($len -gt $bytes -and $lines.Count -gt 1) { $lines = $lines[1..($lines.Count - 1)] }

    $turns = New-Object Collections.ArrayList   # newest first
    $asst  = New-Object Collections.ArrayList   # text blocks of one reply, in order

    for ($i = $lines.Count - 1; $i -ge 0; $i--) {
        if ($turns.Count -ge $CtxMaxTurns) { break }
        $ln = $lines[$i]
        if ($ln.Length -lt 40) { continue }
        # cheap string gates before the parse. PowerShell 5.1's ConvertFrom-Json
        # is slow, and tool results are the biggest lines in the file - this is
        # what keeps a 1MB tail from costing seconds.
        if ($ln.Contains('"isSidechain":true')) { continue }
        if ($ln.Contains('"toolUseResult"'))    { continue }
        if ($ln.Contains('"isMeta":true'))      { continue }
        $isUser = $ln.Contains('"type":"user"')
        if (-not ($isUser -or $ln.Contains('"type":"assistant"'))) { continue }

        try { $o = $ln | ConvertFrom-Json } catch { continue }
        $txt = Get-MessageText $o.message
        if (-not $txt) { continue }

        if (-not $isUser) {
            # a reply is written one line per content block, so a turn has to be
            # reassembled from the consecutive assistant lines above its prompt
            [void]$asst.Insert(0, $txt)
            continue
        }
        if ($asst.Count) {
            [void]$turns.Add(@{ role = 'assistant'; text = ($asst -join "`n") })
            $asst.Clear()
        }
        $u = Get-CleanUserText $txt
        if ($u) { [void]$turns.Add(@{ role = 'user'; text = $u }) }
    }
    if ($asst.Count -and $turns.Count -lt $CtxMaxTurns) {
        [void]$turns.Add(@{ role = 'assistant'; text = ($asst -join "`n") })
    }

    $turns.Reverse()   # chronological
    return $turns
}

function Get-ContextBlock {
    $s = Get-SessionInfo
    if (-not $s) { return $null }
    $p = Get-TranscriptPath $s
    if (-not $p) { return $null }
    $turns = Get-RecentTurns $p
    if (-not $turns -or $turns.Count -eq 0) { return $null }

    $n = $turns.Count
    $rendered = @()
    $elided = 0
    for ($i = 0; $i -lt $n; $i++) {
        # what the user typed is short and dense, so it is never worth trimming;
        # replies are the bulk, and the newest get the bigger budget because
        # "the second one" usually points at the last thing that was said
        $cap = if ($turns[$i].role -eq 'user') { $CtxUserCap }
               elseif ($i -ge $n - 2)          { $CtxRecentCap }
               else                            { $CtxOlderCap }
        $t = Get-Trimmed $turns[$i].text $cap
        if ($t.Length -lt (($turns[$i].text -replace '\s+', ' ').Trim().Length)) { $elided++ }
        $rendered += ('{0}: {1}' -f $turns[$i].role, $t)
    }
    while ($rendered.Count -gt 1 -and (($rendered -join "`n").Length -gt $CtxTotalCap)) {
        $rendered = $rendered[1..($rendered.Count - 1)]
    }
    return [pscustomobject]@{
        Text    = ($rendered -join "`n")
        Turns   = $rendered.Count
        Elided  = $elided   # turns that hit their cap - "why did that not resolve?"
        Session = $s.sessionId
    }
}

if ($Probe) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $c = Get-ContextBlock
    if (-not $c) { Line 'no conversation context resolved' 203; exit 1 }
    Line "session $($c.Session)  |  $($c.Turns) turns  |  $($c.Elided) truncated  |  $($c.Text.Length) chars  |  $('{0:N0}ms' -f $sw.Elapsed.TotalMilliseconds)" 45
    Line ''
    Line $c.Text 250
    exit 0
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

# Never let context-gathering break the rewrite: no session, no transcript or a
# malformed line all degrade to the old context-free behaviour.
$ctx = $null
try { $ctx = Get-ContextBlock } catch { Log "context unavailable: $($_.Exception.Message)" }

Line ''
Say "$([char]0x256D)$([char]0x2500) " 240
Say 'PROMPT BOOST ' 45
Say "$Model " 111
if ($withContext) { Say '+context ' 213 }
if ($ctx) { Say "$($ctx.Turns) turns " 78 } else { Say 'no convo ' 214 }
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

# One shape for every call, so the rewriter never has to guess whether a block
# is missing or empty. Conversation first, draft last: the thing to be rewritten
# is the last thing the model reads.
$convo = if ($ctx) { $ctx.Text } else { '(none available)' }
$payload = "<recent_conversation>`n$convo`n</recent_conversation>`n`n<draft>`n$trim`n</draft>"

$sw = [Diagnostics.Stopwatch]::StartNew()
$proc = [Diagnostics.Process]::Start($psi)
$proc.StandardInput.Write($payload)
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

# Last line of defence: writing meta-commentary into the buffer is how a
# clarifying question ends up submitted as a prompt.
#
# These patterns must match what the rewriter says TO THE USER, not what a
# rewritten prompt legitimately says. A bare '^Can you' is too broad now that the
# conversation is supplied - "can we make it faster" rightly comes back as
# "Can you speed up X", and the old pattern threw that away. What actually marks
# a failure is asking the user to supply something.
$bad = @(
    '^\s*(I need|I''ll need|I cannot|I can''t|To rewrite|Which one|Which of)'
    '^\s*(Could|Can) you (please )?(clarify|specify|provide|confirm|tell me|share|paste|elaborate)'
    '^\s*Please (provide|clarify|specify|confirm|paste|share)'
    '(need|needs|require|requires|without) (more |additional |further )?(clarification|context|information about)'
    "I'?ll rewrite|rewrite your (request|prompt)|your request as a"
    '^\s*(Sure|Certainly|Here(''s| is) the)'
)
$looksMeta = $false
foreach ($re in $bad) { if ($clean -imatch $re) { $looksMeta = $true; break } }

[Console]::Write("`r$ESC[2K")

if ($looksMeta) {
    Log "REJECTED meta-output (kept original): $($clean.Substring(0, [Math]::Min(70, $clean.Length)) -replace '\s+', ' ')"
    Say "$([char]0x2570)$([char]0x2500) " 240
    Line 'not a rewrite - original kept' 214
    Start-Sleep -Milliseconds 1500
    exit 0
}

if ($proc.ExitCode -ne 0 -or $clean.Length -eq 0) {
    Say "$([char]0x2570)$([char]0x2500) " 240
    Line "boost failed (exit $($proc.ExitCode)) - prompt left untouched" 203
    if ($err) { Line ("   " + ($err.Trim() -split "`n")[0]) 240 }
    Start-Sleep -Milliseconds 1400
    exit 0
}

[IO.File]::WriteAllText($File, $clean)
Log ("ok {0:N1}s {1}->{2} chars  ctx {3}" -f $sw.Elapsed.TotalSeconds, $trim.Length, $clean.Length,
     $(if ($ctx) { "$($ctx.Turns) turns/$($ctx.Text.Length) chars" } else { 'none' }))
Say "$([char]0x2570)$([char]0x2500) " 240
Say "$([char]0x2713) " 78
Line "$('{0:N1}s' -f $sw.Elapsed.TotalSeconds)  $($trim.Length) $([char]0x2192) $($clean.Length) chars   (original saved to ~/.claude/prompt-boost.last.txt)" 244
Start-Sleep -Milliseconds 550
exit 0
