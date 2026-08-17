# Pass 05 — Retry / Backoff

**Weight:** 2×

## What this audits
Do network calls retry transient failures (429, 503, timeouts) with
exponential backoff + jitter? Or do they fail-and-give-up?

## Tier 0
```bash
grep -rln --include='*.swift' 'retry\|backoff\|jitter\|Task\.sleep.*nanoseconds' <project-root>
```

## Scoring
| Score | Criteria |
|---|---|
| 5 | Centralized retry helper; exp backoff + jitter; only retries transient (429, 503, timeout); max attempts cap |
| 4 | Per-service retry; sound logic |
| 3 | Some retries but no backoff (DDoSes the server) |
| 2 | Retries on every error including 4xx (worsens problem) |
| 1 | Zero retry logic |

## Recommended fix
```swift
struct Retry {
    static func with<T>(maxAttempts: Int = 3,
                        baseDelay: Duration = .milliseconds(200),
                        operation: @escaping () async throws -> T) async throws -> T {
        var attempt = 0
        while true {
            do { return try await operation() }
            catch {
                attempt += 1
                guard attempt < maxAttempts,
                      Retry.isTransient(error) else { throw error }
                let jitter = Double.random(in: 0...1)
                let delay = baseDelay * Int(pow(2.0, Double(attempt))) + .milliseconds(Int(jitter * 100))
                try await Task.sleep(for: delay)
            }
        }
    }

    static func isTransient(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            return [.timedOut, .networkConnectionLost, .notConnectedToInternet].contains(urlError.code)
        }
        return false
    }
}
```

## What NOT to flag
- Read-only static configuration loads (no retry needed)
- User-initiated actions (let the user decide to retry)
