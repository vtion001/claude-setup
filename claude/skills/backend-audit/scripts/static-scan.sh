#!/usr/bin/env bash
# static-scan.sh — Tier 0 grep signatures for backend-audit passes.
# Usage: static-scan.sh [TARGET_DIR]   (defaults to current directory)
# Read-only. Emits candidate signals grouped by pass. Tier 2 (AI) filters false positives.
set -uo pipefail   # not -e: a pass with zero hits must not abort the script

DIR="${1:-.}"
cd "$DIR"

if command -v rg >/dev/null 2>&1; then
  # -e marks the pattern explicitly so patterns starting with '-' (e.g. ->where() ) aren't read as flags.
  SEARCH() { rg -n -i --no-messages -g '!node_modules' -g '!vendor' -g '!.git' -g '!dist' -g '!build' -e "$1" . 2>/dev/null | head -40; }
else
  # -E for ERE alternation; -e marks the pattern so leading '-' is not parsed as a flag.
  SEARCH() { grep -rEnI -i --exclude-dir=node_modules --exclude-dir=vendor --exclude-dir=.git --exclude-dir=dist --exclude-dir=build -e "$1" . 2>/dev/null | head -40; }
fi

section() { echo; echo "=================================================================="; echo "## $1"; echo "------------------------------------------------------------------"; }
note()    { echo ">> $1"; }
emit()    { local out; out="$(SEARCH "$1")"; if [ -n "$out" ]; then echo "$out"; else echo "(no hits)"; fi; }

echo "# backend-audit static scan — $DIR"

section "Pass 2 · fetch / N+1 — queries inside loops, lazy loads, SELECT *"
note "Query calls (review whether any sit inside a foreach/for/while):"
emit '->(find|where|get|row|result|first)\(|\.(findUnique|findFirst|findByPk)\(|\.objects\.(get|filter)\('
note "SELECT * / unprojected reads:"
emit "select\\(['\"]\\*|SELECT \\*"
note "await inside .map (possible per-item query):"
emit '\.map\(async'
note "Missing eager-load helpers (if these are ABSENT near relations, suspect N+1):"
emit 'with\(|select_related|prefetch_related|include:\s*\{'

section "Pass 3 · cache — response cache & HTTP cache headers"
note "Cache usage:"
emit 'Cache::|->cache\(|cache\(\)->|redis|memcached|createClient'
note "HTTP cache headers (absence on cacheable GETs = finding):"
emit 'Cache-Control|ETag|Last-Modified|stale-while-revalidate'

section "Pass 4 · rate-limit — outbound 429 handling & inbound throttle"
note "Outbound rate-limit awareness:"
emit 'Retry-After|X-RateLimit|429'
note "Inbound throttling middleware:"
emit 'Throttler|express-rate-limit|slowapi|ratelimit|rack-attack'

section "Pass 5 · resilience — timeouts, retries, breakers, swallowed errors"
note "Timeouts set on outbound calls (absence near HTTP calls = finding):"
emit 'timeout|CURLOPT_TIMEOUT|connect_timeout|http\.Client\(timeout'
note "Retry / backoff:"
emit 'retry|backoff|exponential'
note "Circuit breaker:"
emit 'circuit|breaker|opossum|pybreaker|resilience4j'
note "Possibly swallowed errors (empty/comment-only catch):"
emit 'catch\s*\([^)]*\)\s*\{\s*\}'

section "Pass 6 · pagination & payload"
note "Unbounded list reads (findAll / .all() / objects.all without limit):"
emit 'findAll\(\)|\.all\(\)|objects\.all\(\)'
note "Limit/offset/cursor present?"
emit 'limit\(|->limit|offset|cursor|paginate'
note "Compression enabled?"
emit 'gzip|brotli|compress'

section "Pass 7 · pooling — connection reuse"
note "Pool config:"
emit 'pool|pConnect|CONN_MAX_AGE|max_overflow|maxPoolSize|pool_size'
note "Per-request client/connection construction (anti-pattern if inside handlers):"
emit 'new (Client|GuzzleClient|PDO|Pool)\(|createConnection\('

section "Pass 8 · database — indexing, transactions, locking, migrations"
note "Index creation in migrations (and whether FK/WHERE columns are covered):"
emit 'addKey|->index\(|CREATE INDEX|add_index|Schema::|createIndex'
note "Transaction scope (flag if wrapping network calls or long loops):"
emit 'beginTransaction|DB::transaction|transaction\.atomic|START TRANSACTION|->transStart'
note "Explicit row locks held across work:"
emit 'lockForUpdate|FOR UPDATE|SELECT .* LOCK'
note "Migration statements that take heavy/table locks (review for deploy impact):"
emit 'ALTER TABLE|ADD COLUMN|DROP COLUMN|CREATE INDEX'
note "Postgres index builds — confirm CONCURRENTLY is used (non-concurrent blocks writes):"
emit 'CONCURRENTLY'

section "Pass 9 · latency — slow query shapes & inline heavy work"
note "Leading-wildcard LIKE / unindexed scans:"
emit "LIKE ['\"]%|ORDER BY|COUNT\\(\\*\\)"
note "Inline side-effects that probably belong in a queue (see Pass 10):"
emit 'mail\(|->send\(|Mail::|sendmail|Imagick|gd_|render|exec\('

section "Pass 10 · async — background jobs, queues, blocking"
note "Queue / worker infra present?"
emit 'queue|dispatch\(|->push\(|celery|sidekiq|bullmq|BullMQ|rq\.|spark'
note "Dead-letter / retry / max-attempts handling:"
emit 'dead.?letter|DLQ|max_attempts|maxRetries|->tries|backoff'
note "Event-loop / thread blocking (Node *Sync, Python blocking in async):"
emit 'readFileSync|writeFileSync|execSync|crypto\.[a-zA-Z]+Sync|time\.sleep|requests\.(get|post)'

section "Pass 11 · contract — idempotency, versioning, error envelope, webhooks"
note "Idempotency key handling on unsafe writes:"
emit 'Idempotency-?Key|idempotency_key|idempotencyKey'
note "API versioning:"
emit '/v[0-9]|api/v|Accept-Version|X-API-Version'
note "Error envelope smell — returning HTTP 200 on an error branch:"
emit "status[(_ ]?200.*error|setStatusCode\\(200\\).*error|'status'.*'error'"
note "OpenAPI / Swagger contract present?"
emit 'openapi|swagger'
note "Webhook handling (idempotent processing, signature verify, fast ack):"
emit 'webhook|X-Signature|HMAC|verifySignature'

section "Pass 12 · observability — logging, metrics, tracing, health"
note "Structured logging vs raw debug prints (raw prints in handlers = finding):"
emit 'var_dump\(|print_r\(|console\.log\(|\bdd\(|\bdie\(|System\.out\.print'
note "Structured/log framework present?"
emit 'Monolog|log\.(info|error|warn)|logger\.|structlog|winston|pino'
note "Correlation / request ID propagation:"
emit 'request_id|correlation_id|X-Request-Id|traceId|trace_id'
note "Metrics / tracing / APM:"
emit 'opentelemetry|prometheus|statsd|datadog|newrelic|Sentry'
note "Health / readiness endpoint:"
emit '/health|/healthz|/readyz|liveness|readiness'

section "Pass 13 · deps — usage hygiene"
note "ORM lazy defaults / chatty patterns (cross-check with Pass 2):"
emit 'lazy|hasMany|belongsTo|relationship\('

echo
echo "=================================================================="
echo "Static scan complete. Hits are CANDIDATES — confirm context (loop? hot path?)"
echo "before scoring. See references/passes.md for what each signal means."
