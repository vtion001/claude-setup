# ship-loop: appends a line every time a review subagent (sentinal/verity/
# aesthetica) finishes, as a deterministic audit trail the LLM doesn't have
# to remember to keep.

$stdin = [Console]::In.ReadToEnd()
$json = $stdin | ConvertFrom-Json

$logDir = Join-Path $env:USERPROFILE ".claude\hooks\ship-loop\logs"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

$entry = [PSCustomObject]@{
    time    = (Get-Date).ToString("o")
    agent   = $json.agent_type
    session = $json.session_id
    cwd     = $json.cwd
} | ConvertTo-Json -Compress

Add-Content -Path (Join-Path $logDir "review-log.jsonl") -Value $entry
exit 0
