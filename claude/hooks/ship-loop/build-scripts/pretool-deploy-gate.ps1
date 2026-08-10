# ship-loop: blocks deploy-shaped Bash commands unless a fresh passing GATE
# marker exists for this working directory. Backstop only - the primary
# control is the ship-loop skill's own GATE step and the user confirmation
# in its SHIP step.

$stdin = [Console]::In.ReadToEnd()
$json = $stdin | ConvertFrom-Json
$cmd = [string]$json.tool_input.command

if ($cmd -notmatch '(?i)(vercel\s+.*--prod|render\s+deploy|artisan\s+migrate.*--force|git\s+push\s+(origin|upstream)\s+(main|master)|npm\s+publish|firebase\s+deploy)') {
    exit 0
}

function Get-GateMarkerPath($cwd) {
    $md5 = [System.Security.Cryptography.MD5]::Create()
    $hash = [System.BitConverter]::ToString($md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($cwd))) -replace '-', ''
    return Join-Path $env:TEMP "ship-loop-gate-$hash.marker"
}

$marker = Get-GateMarkerPath $json.cwd

if (Test-Path $marker) {
    $age = (Get-Date) - (Get-Item $marker).LastWriteTime
    if ($age.TotalHours -lt 4) {
        exit 0
    }
}

[Console]::Error.WriteLine("ship-loop: deploy-shaped command blocked - no fresh passing quality gate recorded for this directory in the last 4 hours. Run the ship-loop GATE stage first, or tell Claude explicitly to bypass this check.")
exit 2
