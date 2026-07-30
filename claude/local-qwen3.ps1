param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$ClaudeArgs
)

$env:ANTHROPIC_BASE_URL = "http://127.0.0.1:8787"
$env:ANTHROPIC_AUTH_TOKEN = "ags-local"
$env:ANTHROPIC_MODEL = "qwen3:14b-q4_K_M"
$env:ANTHROPIC_DEFAULT_SONNET_MODEL = "qwen3:14b-q4_K_M"
$env:ANTHROPIC_DEFAULT_OPUS_MODEL = "qwen3:14b-q4_K_M"
$env:ANTHROPIC_DEFAULT_HAIKU_MODEL = "qwen3:14b-q4_K_M"

if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
  throw "Claude Code is not on the Windows PATH. Run this launcher from the environment where the claude command is installed."
}

& claude @ClaudeArgs
