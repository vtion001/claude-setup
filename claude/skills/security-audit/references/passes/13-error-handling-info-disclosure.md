# Pass 13: Error Handling & Information Disclosure

**Weight:** 3% of Security Score
**OWASP Mapping:** A10:2025 (Mishandling of Exceptional Conditions), WSTG-ERR-01 (Improper Error Handling), WSTG-ERR-02 (Stack Traces)
**Automation Level:** 85% fully automated, 10% AI-assisted, 5% manual judgment
**Difficulty:** Low to Medium -- most checks can be automated, but fail-open detection requires contextual understanding

---

## Overview

Error handling and information disclosure vulnerabilities expose internal application details that assist attackers in crafting targeted exploits. Stack traces reveal framework versions, file paths, and database schemas. Debug endpoints expose configuration and secrets. Backup files contain source code. These findings are rarely critical on their own but serve as force multipliers for other attack vectors.

**Key Principle:** Every error response, debug endpoint, and information leak reduces the attacker's effort. The goal is to ensure the application reveals nothing about its internals to unauthorized users while maintaining useful error messages for developers through proper logging.

---

## Tier 0: Static Analysis (Code Review)

### 0.1 Error Handling Middleware

Search for centralized error handling configuration and verify it suppresses details in production.

**Grep patterns:**

```
# Express.js error handler
Pattern: app\.(use|set)\(.*err(or)?
Files: **/*.{js,ts}
Context: Check if error handler sends stack traces to client

# Express debug mode
Pattern: app\.set\(['"]env['"],\s*['"]development['"]\)
Files: **/*.{js,ts}
Context: Development mode enables verbose errors

# Laravel exception handler
Pattern: class\s+Handler\s+extends\s+ExceptionHandler
Files: **/*.php
Context: Check render() method for information disclosure

# Django DEBUG setting
Pattern: DEBUG\s*=\s*True
Files: settings.py, **/settings/*.py, .env*
Context: DEBUG=True exposes full stack traces and SQL queries

# Spring Boot error configuration
Pattern: server\.error\.(include-stacktrace|include-message|include-binding-errors)
Files: application.properties, application.yml
Context: Should be set to "never" in production

# ASP.NET error mode
Pattern: <customErrors\s+mode=["']Off["']|UseDeveloperExceptionPage
Files: web.config, **/*.cs
Context: Developer error pages should not be enabled in production

# General NODE_ENV check
Pattern: NODE_ENV.*(!==?|!==)\s*['"]production['"]
Files: **/*.{js,ts}
Context: Code that behaves differently outside production
```

### 0.2 Debug Mode Flags

Search for debug configuration that should be disabled in production.

**Grep patterns:**

```
# Debug flags in configuration
Pattern: (DEBUG|VERBOSE|TRACE)\s*[=:]\s*(true|1|yes|on)
Files: **/*.{env,yml,yaml,json,ini,conf,config}
Context: Debug flags should be false in production

# Debug logging in source code
Pattern: (console\.(log|debug|trace|dir|table)|print\(|puts\s|var_dump|dd\(|dump\(|echo\s|System\.out\.print)
Files: **/*.{js,ts,py,rb,php,java}
Context: Check if these are in production code paths (not just tests)

# Debug routes/endpoints
Pattern: (route|get|post|app\.).*(['"].*debug|['"].*test|['"].*phpinfo|['"].*info|['"].*status|['"].*health)
Files: **/*.{js,ts,py,rb,php}
Context: Debug endpoints should be removed or protected in production

# Verbose error responses in code
Pattern: (res\.json|res\.send|return.*response|JsonResponse)\s*\(\s*\{[^}]*(stack|trace|error\.|err\.|exception)
Files: **/*.{js,ts,py,rb,php}
Context: Error responses should not include stack traces
```

### 0.3 Sensitive Data in Console/Logs

Search for logging statements that may output sensitive data.

**Grep patterns:**

```
# Logging sensitive fields
Pattern: (console\.log|logger\.(info|debug|error|warn)|log\.(info|debug|error|warn)|print|puts).*\b(password|token|secret|key|credential|ssn|credit.?card|cvv|authorization)\b
Files: **/*.{js,ts,py,rb,php,java,go}
Context: Sensitive data should never appear in log output

# Request/response body logging (may contain credentials)
Pattern: (console\.log|logger\.).*\b(req\.body|request\.body|response\.data|res\.body)\b
Files: **/*.{js,ts,py,rb,php}
Context: Full request/response logging may capture credentials

# Error logging with full error object
Pattern: (console\.error|logger\.error)\s*\(\s*(err|error|e|ex|exception)\s*\)
Files: **/*.{js,ts,py}
Context: Logging full error objects may include sensitive context
```

---

## Tier 1: Automated Scanning (Burp MCP + Playwright)

### Check 13.1: Stack Trace Exposure

**Tools:** Burp Intruder
**WSTG:** WSTG-ERR-02

```
WORKFLOW:
1. Identify input parameters across the application
2. Send malformed inputs designed to trigger errors
3. Analyze error responses for stack trace information

BURP INTRUDER PAYLOADS:
- Type mismatch: Send string where integer expected ("abc" for ?id=)
- Null values: Send null, undefined, None for required fields
- Oversized input: Send 10KB+ strings for short fields
- Special characters: Send ', ", <, >, \, /, `, %00
- Invalid JSON: Send malformed JSON body { "key": }
- Invalid Content-Type: Send JSON body with text/plain content type
- Missing required fields: Remove required parameters
- Invalid method: Send POST to GET endpoint, DELETE to POST endpoint

DETECTION PATTERNS IN RESPONSES:
- "at " followed by file path (Node.js/JavaScript stack trace)
- "File " + path + ", line" (Python traceback)
- "\.java:\d+" (Java stack trace)
- "#\d+\s+\/" (PHP stack trace)
- "Exception in thread" (Java)
- "Traceback (most recent call last)" (Python)
- SQL syntax error messages with query text
- "SQLSTATE" or "ORA-" error codes

INDICATORS OF VULNERABILITY:
- Full file paths visible in error response
- Framework/language version numbers in stack trace
- Database connection strings in error output
- Internal class/method names exposed
- Third-party library versions revealed
```

### Check 13.2: Debug Mode Detection

**Tools:** Burp Scanner + Playwright
**WSTG:** WSTG-ERR-01

```
BURP SCANNER:
- Run passive scan on all responses looking for debug indicators
- Check response headers for debug-related headers

PLAYWRIGHT WORKFLOW:
1. Navigate to common debug endpoints:
   - /debug, /debug/info, /debug/vars
   - /_debug, /__debug__
   - /phpinfo.php, /info.php
   - /server-info, /server-status
   - /actuator, /actuator/env, /actuator/health
   - /elmah.axd, /trace.axd
   - /_profiler, /_wdt (Symfony)
   - /graphql (with introspection query)
   - /swagger, /swagger-ui, /api-docs
   - /metrics, /prometheus
2. Check response status (200 = potentially exposed)
3. Take screenshot of any accessible debug pages

DETECTION IN RESPONSES:
- "X-Debug-Token" header
- "X-Debug-Mode" header
- "Server-Timing" with internal service names
- Django debug toolbar HTML
- Laravel Telescope dashboard
- Spring Boot Actuator endpoints
- PHP Xdebug headers

INDICATORS OF VULNERABILITY:
- Debug endpoint accessible without authentication
- Environment variables exposed via debug endpoint
- Database configuration visible
- Internal service architecture revealed
```

### Check 13.3: Source Code in Error Responses

**Tools:** Burp analysis
**WSTG:** WSTG-ERR-01

```
WORKFLOW:
1. Trigger errors across all endpoints (use Check 13.1 payloads)
2. Search error responses for source code snippets

DETECTION PATTERNS:
- Syntax-highlighted code blocks in HTML error pages
- "around line" or "near line" with code context
- Template source with {{ }} or <% %> syntax visible
- SQL queries with table/column names
- Regular expressions from validation rules
- Configuration values (connection strings, file paths)

BURP PASSIVE SCAN RULES:
- Check for HTML responses containing code-like patterns
- Flag responses > 1KB that contain programming language syntax
- Identify responses with file path patterns (/var/www, C:\, /home/)
```

### Check 13.4: Database Information in Errors

**Tools:** Burp Intruder
**WSTG:** WSTG-ERR-01, related to A05:2025

```
WORKFLOW:
1. Inject SQL-triggering characters into all input parameters
2. Analyze error responses for database schema information

PAYLOADS:
- Single quote: '
- Double quote: "
- Semicolon: ;
- Comment markers: --, /*, #
- Union: ' UNION SELECT 1--
- Boolean: ' OR '1'='1
- Time-based: ' OR SLEEP(1)--

DETECTION PATTERNS:
- Table names: "table 'users'", "relation \"orders\""
- Column names: "column 'password'", "Unknown column"
- Database version: "MySQL", "PostgreSQL", "MariaDB", "MSSQL"
- Query structure: "SELECT ... FROM ... WHERE"
- Schema info: "pg_catalog", "information_schema"
- Connection info: "localhost:5432", "127.0.0.1:3306"
- ORM-generated SQL: Sequelize, Prisma, TypeORM, SQLAlchemy error format

INDICATORS OF VULNERABILITY:
- Database type and version revealed
- Table/column names exposed
- Full SQL query visible in error
- Connection string details leaked
```

### Check 13.5: Path Disclosure

**Tools:** Burp Scanner
**WSTG:** WSTG-ERR-01

```
WORKFLOW:
1. Trigger errors and scan responses for filesystem paths
2. Check headers for path information
3. Check static file responses for path hints

DETECTION PATTERNS:
- Unix paths: /var/www/, /home/, /opt/, /usr/, /app/, /srv/
- Windows paths: C:\inetpub\, C:\Users\, C:\Program Files\
- Container paths: /usr/src/app/, /workspace/
- Relative paths that reveal project structure: ./src/, ../config/
- Webpack paths: webpack:///src/, webpack-internal:///

CHECK HEADERS:
- X-SourceMap: file path to source maps
- Content-Location: internal path references
- Link: internal URL references

INDICATORS OF VULNERABILITY:
- Full filesystem path to application root
- Username in path (/home/deploy/, /Users/admin/)
- Framework-specific paths revealing technology stack
- Container orchestration paths revealing infrastructure
```

### Check 13.6: Version Disclosure

**Tools:** Burp passive scan
**WSTG:** WSTG-INFO-02, WSTG-INFO-08

```
WORKFLOW:
1. Analyze all response headers for version information
2. Check HTML meta tags and comments for version strings
3. Check JavaScript files for library version comments

HEADERS TO CHECK:
- Server: Apache/2.4.51, nginx/1.21.4, Microsoft-IIS/10.0
- X-Powered-By: Express, PHP/8.1.0, ASP.NET
- X-AspNet-Version: 4.0.30319
- X-Generator: WordPress 6.0, Drupal 9
- X-Drupal-Cache, X-Drupal-Dynamic-Cache
- X-WordPress-Nonce (reveals WordPress)
- Via: header with proxy/CDN version info

HTML/META CHECKS:
- <meta name="generator" content="...">
- HTML comments: <!-- WordPress 6.0 -->
- CSS/JS version query strings: ?v=3.2.1
- JavaScript library comments: /*! jQuery v3.6.0 */

INDICATORS OF VULNERABILITY:
- Specific version numbers that map to known CVEs
- Framework identification enabling targeted attacks
- Multiple version disclosures building a detailed technology profile
```

### Check 13.7: Custom Error Pages

**Tools:** Burp Intruder
**WSTG:** WSTG-ERR-01

```
WORKFLOW:
1. Request various error-triggering URLs
2. Verify all error pages are custom (not framework defaults)
3. Check that error pages do not leak information

ERROR TRIGGERS:
- 404: /nonexistent-page-abc123
- 403: /admin (if restricted)
- 405: Wrong HTTP method on valid endpoint
- 500: Malformed request body
- 400: Invalid query parameters
- 413: Oversized request body (send 10MB)
- 414: Very long URL (send 8KB+ URL)
- 431: Many/large headers

CHECK EACH ERROR PAGE FOR:
- Default framework error page (Express, Django, Laravel, Rails, Spring)
- Server information in error page
- Stack traces or code snippets
- Different level of detail between error codes
- Consistent branding (should match application design)

INDICATORS OF VULNERABILITY:
- Default framework error page in production
- Error page reveals technology stack
- Different error pages for different error types (inconsistent handling)
- Error page includes internal URLs or paths
```

### Check 13.8: robots.txt and Sitemap Sensitive Paths

**Tools:** WebFetch
**WSTG:** WSTG-INFO-03

```
WORKFLOW:
1. Fetch and parse robots.txt
2. Fetch and parse sitemap.xml
3. Analyze for sensitive path disclosure

WEBFETCH:
- GET /robots.txt
- GET /sitemap.xml
- GET /sitemap_index.xml
- GET /sitemaps/sitemap.xml

ANALYZE robots.txt FOR:
- Disallowed admin paths: /admin, /administrator, /wp-admin
- Disallowed API paths: /api/internal, /api/v1/admin
- Disallowed sensitive paths: /backup, /config, /db, /logs
- Disallowed staging/test paths: /staging, /test, /dev

ANALYZE sitemap.xml FOR:
- Internal/admin URLs that should not be indexed
- API endpoint URLs
- User-specific URLs revealing user IDs or usernames
- Staging/development URLs

INDICATORS OF VULNERABILITY:
- robots.txt reveals admin panel location
- robots.txt reveals API endpoint structure
- Sitemap includes authenticated/admin pages
- Sensitive directories disclosed via Disallow rules
```

### Check 13.9: HTML Comments with Developer Notes

**Tools:** Playwright + Grep
**WSTG:** WSTG-INFO-05

```
PLAYWRIGHT SCRIPT:
// Extract all HTML comments from the page
(() => {
  const comments = [];
  const iterator = document.createNodeIterator(
    document.documentElement,
    NodeFilter.SHOW_COMMENT
  );
  let node;
  while (node = iterator.nextNode()) {
    const text = node.textContent.trim();
    if (text && text.length > 5) {
      comments.push({
        text: text.substring(0, 200),
        parentTag: node.parentElement ? node.parentElement.tagName : 'unknown'
      });
    }
  }
  return { totalComments: comments.length, comments };
})()

GREP (source code):
Pattern: <!--.*?(TODO|FIXME|HACK|BUG|XXX|TEMP|DEBUG|password|secret|key|token|credential|admin|internal)
Files: **/*.{html,ejs,hbs,pug,jsx,tsx,vue,svelte,php}
Context: Developer notes that should be removed before production

INDICATORS OF VULNERABILITY:
- TODO/FIXME comments revealing known security issues
- Comments containing credentials or API keys
- Comments describing internal architecture or logic
- Comments with developer names/emails
- Commented-out code with debug functionality
```

### Check 13.10: Backup Files (.bak, .old, .tmp, .swp)

**Tools:** Burp Intruder
**WSTG:** WSTG-CONF-04

```
WORKFLOW:
1. For each known page/script URL, test backup file extensions
2. Check common backup file locations

BURP INTRUDER CONFIGURATION:
For each URL like /path/file.ext, test:
- /path/file.ext.bak
- /path/file.ext.old
- /path/file.ext.orig
- /path/file.ext.save
- /path/file.ext.swp
- /path/file.ext.swo
- /path/file.ext~
- /path/file.ext.tmp
- /path/file.ext.backup
- /path/file.ext.copy
- /path/file.bak
- /path/.file.ext.swp (vim swap)
- /path/#file.ext# (emacs backup)

COMMON BACKUP LOCATIONS:
- /backup/
- /backups/
- /bak/
- /old/
- /archive/
- /db.sql
- /database.sql
- /dump.sql
- /data.sql
- /site.tar.gz
- /site.zip
- /www.zip

INDICATORS OF VULNERABILITY:
- Backup file returns 200 with source code content
- SQL dump file accessible (contains database structure and data)
- Archive file accessible (contains full application source)
- Swap files reveal editor-in-use and file contents
```

### Check 13.11: Git/SVN Directory Exposure

**Tools:** Burp + WebFetch
**WSTG:** WSTG-CONF-05

```
WORKFLOW:
1. Check for version control directories accessible via HTTP
2. If accessible, attempt to reconstruct source code

URLS TO TEST:
- GET /.git/HEAD
- GET /.git/config
- GET /.git/index
- GET /.git/refs/heads/main
- GET /.git/refs/heads/master
- GET /.git/logs/HEAD
- GET /.svn/entries
- GET /.svn/wc.db
- GET /.hg/store/data
- GET /.bzr/branch/branch.conf
- GET /CVS/Root
- GET /CVS/Entries

DETECTION:
- .git/HEAD returns: "ref: refs/heads/main" or similar
- .git/config returns: Git configuration with remote URLs
- .svn/entries returns: SVN metadata

INDICATORS OF VULNERABILITY:
- Any version control file accessible (200 response with expected content)
- Git config reveals remote repository URL (potentially private repo)
- Git log reveals commit history with author emails
- Full source code reconstructable from exposed .git directory
```

### Check 13.12: Fail-Open Detection

**Tools:** Burp Repeater
**WSTG:** Related to A10:2025

```
WORKFLOW:
1. Identify authentication/authorization checkpoints
2. Trigger errors at these checkpoints
3. Check if errors result in access being granted (fail-open)

SPECIFIC TESTS:
a) Send malformed authentication token (corrupted JWT, invalid format)
   - Does the server reject or silently accept?
b) Send request with missing authorization header entirely
   - Does the server return 401/403 or process the request?
c) Trigger database error during authorization check
   - Send request that causes DB timeout; does access default to granted?
d) Send conflicting authorization signals
   - Valid session cookie + invalid JWT: which takes precedence?
e) Exceed rate limiter, then send authenticated request
   - Does rate limiting error bypass authentication?
f) Send request with empty/null role
   - Does missing role default to admin or user?

INDICATORS OF VULNERABILITY:
- Access granted when authentication errors occur
- Default role is privileged (admin instead of guest)
- Error in authorization check results in access being granted
- Missing authentication token treated as valid
- Rate limiter or WAF error bypasses security controls
```

---

## Tier 2: AI Judgment Questions

### Question 1: Error Handling Consistency
Are all error paths handled consistently across the application? Is there a centralized error handler, or do individual routes handle errors differently? Could an attacker map the application's internal structure by comparing error responses?

### Question 2: Production vs. Development Configuration
Is there clear separation between development and production error handling? Are there any code paths where debug information could leak in production due to environment variable misconfiguration?

### Question 3: Information Value Assessment
What is the combined value of all information disclosed? While individual disclosures may be low severity, does the aggregate reveal enough to significantly reduce attack complexity? (Technology stack + version + paths + database type = targeted exploit)

### Question 4: Error Response Normalization
Do error responses have consistent timing, content length, and format regardless of the error cause? Could an attacker use response differences to enumerate users, guess credentials, or map internal resources?

### Question 5: Fail-Open Risk
If the error handling middleware itself fails (out of memory, uncaught exception), does the application fail open (grant access) or fail closed (deny access)? Are there circuit breakers for dependent services?

### Question 6: Log Security
Are application logs protected from unauthorized access? Could an attacker with log access pivot to further attacks? Are logs stored in a tamper-evident manner?

---

## Severity Classification

### Critical (P1) -- Score: 0/10
- .git directory fully accessible allowing complete source code reconstruction
- Database dump file accessible via HTTP
- Debug endpoint exposing environment variables including secrets
- Fail-open authentication allowing unauthenticated access on errors

### High (P2) -- Score: 2/10
- Stack traces exposing full file paths and framework versions in production
- Debug mode enabled in production (Django DEBUG=True, Spring Actuator unprotected)
- SQL errors revealing table/column names and query structure
- Backup files containing source code accessible via HTTP
- .env file accessible revealing partial configuration

### Medium (P3) -- Score: 5/10
- Version disclosure in Server/X-Powered-By headers
- robots.txt revealing admin panel and API structure
- HTML comments containing developer notes about security
- Default framework error pages in production
- Source maps accessible in production

### Low (P4) -- Score: 7/10
- Minor version information in response headers
- HTML comments with non-sensitive developer notes
- Inconsistent error page styling (not matching application branding)
- Verbose error messages without stack traces
- Console.log statements in production JavaScript

---

## False Positive Indicators

1. **Intentional Health/Status Endpoints:** /health, /status, /ready endpoints that intentionally expose limited application state for monitoring are not vulnerabilities (unless they expose sensitive details).
2. **Public API Documentation:** Swagger/OpenAPI endpoints that are intentionally public for developer consumption are not information disclosure (verify this is intentional).
3. **Development Environment:** Debug mode and verbose errors in development/staging environments are expected. Only flag for production.
4. **Version Strings in Public Libraries:** jQuery version comments in minified JavaScript that is publicly available anyway are not meaningful disclosures.
5. **robots.txt Disallow for SEO:** Disallowing /search, /filter, /sort for SEO purposes (preventing duplicate content) is not security-sensitive path disclosure.
6. **Generic Error Messages:** Custom error pages that say "Something went wrong" without details are the correct behavior, not a finding.

---

## Remediation

### Stack Trace Suppression
- Implement centralized error handling middleware
- Return generic error messages to clients (e.g., "Internal Server Error")
- Log full error details server-side (never in client responses)
- Use error IDs (correlation IDs) so users can reference errors without seeing details

```javascript
// Express.js example
app.use((err, req, res, next) => {
  const errorId = crypto.randomUUID();
  logger.error({ errorId, err, req: { method: req.method, url: req.url } });
  res.status(err.status || 500).json({
    error: 'An unexpected error occurred',
    errorId,
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack })
  });
});
```

### Debug Mode
- Set NODE_ENV=production, DJANGO_DEBUG=False, RAILS_ENV=production
- Remove or protect all debug endpoints behind authentication
- Use feature flags (not environment variables) for debug tooling
- Remove phpinfo.php, info.php, and similar files from production

### Header Hardening
- Remove Server version: `server_tokens off;` (nginx), `ServerTokens Prod` (Apache)
- Remove X-Powered-By: `app.disable('x-powered-by')` (Express)
- Remove X-AspNet-Version, X-Generator headers

### File Cleanup
- Remove all backup files (.bak, .old, .tmp, .swp) from web root
- Block access to hidden files at web server level:
  ```nginx
  location ~ /\. { deny all; }
  ```
- Block source map access: `location ~* \.map$ { return 404; }`
- Block version control directories: `location ~ /\.(git|svn|hg) { deny all; }`

### robots.txt Hardening
- Do not list sensitive paths in robots.txt (it serves as a roadmap for attackers)
- Use authentication/authorization to protect sensitive paths instead
- Keep robots.txt minimal (Disallow crawl-heavy but non-sensitive paths only)

### Fail-Closed Implementation
- Default to deny access when errors occur
- Implement circuit breakers for dependent services
- Test error paths explicitly in integration tests
- Add monitoring/alerting for error handler failures
