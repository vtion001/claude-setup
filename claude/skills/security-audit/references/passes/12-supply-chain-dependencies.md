# Pass 12: Supply Chain & Dependency Security

**Weight:** 5% of Security Score
**OWASP Mapping:** A03:2025 (Software Supply Chain Failures), A08:2025 (Software/Data Integrity Failures)
**Automation Level:** 80% fully automated, 15% AI-assisted, 5% manual judgment
**Difficulty:** Medium -- most checks are tooling-driven, but typosquatting and CI/CD review require human analysis

---

## Overview

Supply chain attacks target the software development pipeline rather than the application itself. A single compromised dependency can grant an attacker access to every application that uses it. The SolarWinds (2020), Codecov (2021), and ua-parser-js (2021) incidents demonstrated that supply chain attacks can bypass all application-level security controls. OWASP elevated this to position #3 in 2025, with the highest average incidence rate (5.72%) across tested applications.

**Key Principle:** You are only as secure as your least-secure dependency. Every external package, CDN script, CI/CD plugin, and build tool is a trust decision.

---

## Tier 0: Static Analysis (Code Review)

### 0.1 Known CVE Dependencies

Run package manager audit tools to identify dependencies with known vulnerabilities.

**Commands to execute:**

```bash
# Node.js / npm
npm audit --json 2>/dev/null

# Node.js / yarn
yarn audit --json 2>/dev/null

# Node.js / pnpm
pnpm audit --json 2>/dev/null

# Python / pip
pip-audit --format=json 2>/dev/null || pip install pip-audit && pip-audit --format=json

# Python / poetry
poetry show --outdated 2>/dev/null

# Ruby / bundler
bundle audit check --update 2>/dev/null

# PHP / composer
composer audit --format=json 2>/dev/null

# Go
govulncheck ./... 2>/dev/null

# .NET
dotnet list package --vulnerable --include-transitive 2>/dev/null
```

**Grep patterns for manual verification:**

```
# Check for pinned vs. range versions in package.json
Pattern: "[\^~>=<]
Files: package.json, */package.json
Context: Ranges allow automatic minor/patch upgrades that may introduce vulnerabilities

# Check for known vulnerable package names
Pattern: (event-stream|ua-parser-js|colors|faker|node-ipc|peacenotwar|es5-ext)
Files: package.json, package-lock.json, yarn.lock
Context: Packages with known supply chain incidents

# Python requirements without pinned versions
Pattern: ^[a-zA-Z][\w-]*\s*$
Files: requirements.txt, requirements/*.txt
Context: Unpinned dependencies resolve to latest (potentially compromised) version
```

### 0.2 Outdated Dependencies

Check for packages with available security updates.

**Grep patterns:**

```
# Check package age indicators
Pattern: "version":\s*"[01]\."
Files: package.json
Context: Major version 0.x or 1.x packages may be unmaintained

# Check for deprecated packages
Pattern: "deprecated"
Files: package-lock.json, yarn.lock
Context: Deprecated packages no longer receive security fixes

# Check for engines field (Node.js version requirements)
Pattern: "engines"
Files: package.json
Context: Missing engines field means no Node.js version enforcement
```

**Read patterns:**

```
# Check package.json for outdated patterns
Files: package.json, composer.json, Gemfile, requirements.txt, go.mod, Cargo.toml
Look for: Last modified date, version ranges, known-outdated major versions

# Check for Dependabot/Renovate configuration
Files: .github/dependabot.yml, .github/renovate.json, renovate.json
Look for: Automated dependency update configuration
```

### 0.3 Lock File Integrity

Verify lock files exist, are committed, and are consistent with manifest files.

**Grep patterns:**

```
# Check .gitignore for excluded lock files (anti-pattern)
Pattern: (package-lock|yarn\.lock|pnpm-lock|Pipfile\.lock|poetry\.lock|composer\.lock|Gemfile\.lock|go\.sum|Cargo\.lock)
Files: .gitignore, **/.gitignore
Context: Lock files should NEVER be gitignored

# Check for integrity hashes in lock files
Pattern: "integrity":\s*"sha
Files: package-lock.json
Context: Missing integrity hashes = no verification of downloaded packages

# Check for resolved URLs pointing to unexpected registries
Pattern: "resolved":\s*"https?://(?!registry\.npmjs\.org|registry\.yarnpkg\.com)
Files: package-lock.json, yarn.lock
Context: Packages resolved from non-standard registries may be compromised
```

### 0.4 SRI Attributes on CDN Scripts

Check HTML/templates for external scripts loaded without Subresource Integrity.

**Grep patterns:**

```
# External scripts without integrity attribute
Pattern: <script[^>]*src=["']https?://(?!localhost)[^"']+["'][^>]*>
Files: **/*.{html,ejs,hbs,pug,jsx,tsx,vue,svelte}
Context: Check if integrity="sha384-..." attribute is present

# External stylesheets without integrity attribute
Pattern: <link[^>]*href=["']https?://(?!localhost)[^"']+\.css["'][^>]*>
Files: **/*.{html,ejs,hbs,pug,jsx,tsx,vue,svelte}
Context: Check if integrity="sha384-..." attribute is present

# CDN imports in JavaScript (dynamic script loading without SRI)
Pattern: (createElement\(['"]script['"]\)|document\.write.*<script|\.src\s*=\s*['"]https?://)
Files: **/*.{js,ts,jsx,tsx}
Context: Dynamic script loading bypasses SRI
```

### 0.5 Secrets in Git History

Check for accidentally committed secrets.

**Grep patterns:**

```
# .env files committed
Pattern: ^\.env$|^\.env\.(local|production|staging|development)$
Files: .gitignore
Context: Verify .env patterns are gitignored (absence = vulnerability)

# Hardcoded secrets in source code
Pattern: (api[_-]?key|api[_-]?secret|password|secret[_-]?key|access[_-]?token|private[_-]?key)\s*[=:]\s*['"][A-Za-z0-9+/=_-]{8,}['"]
Files: **/*.{js,ts,py,rb,php,java,go,env,yml,yaml,json}
Context: Secrets should come from environment variables, not source code

# AWS/GCP/Azure credentials
Pattern: (AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|[0-9a-f]{32}-us[0-9]{1,2})
Files: **/*
Context: Cloud provider credentials in source code

# Private keys
Pattern: -----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----
Files: **/*
Context: Private keys should never be in source code
```

### 0.6 CI/CD Configuration Security

Check pipeline configurations for secret management and integrity.

**Grep patterns:**

```
# Secrets in CI/CD config (not using secret references)
Pattern: (password|token|key|secret)\s*[:=]\s*['"]?[A-Za-z0-9+/=_-]{8,}
Files: .github/workflows/*.yml, .gitlab-ci.yml, Jenkinsfile, .circleci/config.yml, azure-pipelines.yml, bitbucket-pipelines.yml
Context: Secrets should use ${{ secrets.NAME }} syntax, not plaintext

# Unsafe CI/CD practices
Pattern: (npm install|pip install|go get)(?!.*--frozen-lockfile|.*--ci|.*-r requirements)
Files: .github/workflows/*.yml, .gitlab-ci.yml, Jenkinsfile
Context: CI should use locked dependencies, not resolve latest

# Unpinned GitHub Actions
Pattern: uses:\s*[\w-]+/[\w-]+@(?!v?\d+\.\d+\.\d+|[a-f0-9]{40})
Files: .github/workflows/*.yml
Context: Actions should be pinned to specific SHA or version tag

# Pull request trigger without restrictions
Pattern: pull_request_target
Files: .github/workflows/*.yml
Context: pull_request_target runs with write permissions and secrets
```

---

## Tier 1: Automated Scanning (Burp MCP + Playwright)

### Check 12.1: Known CVE Dependencies

**Tools:** Code analysis + npm audit / pip-audit
**OWASP:** A03:2025

```
WORKFLOW:
1. Read package manifest files (package.json, requirements.txt, etc.)
2. Execute package manager audit commands (see Tier 0 commands)
3. Parse JSON output for severity levels
4. Cross-reference with NVD/GitHub Advisory Database

SEVERITY MAPPING:
- Critical CVE (CVSS >= 9.0): Security Score = Critical
- High CVE (CVSS 7.0-8.9): Security Score = High
- Medium CVE (CVSS 4.0-6.9): Security Score = Medium
- Low CVE (CVSS < 4.0): Security Score = Low

CHECK: Does the project have zero critical/high CVEs in direct dependencies?
CHECK: Are transitive dependency CVEs tracked and addressed?
CHECK: Is there an automated process for CVE monitoring (Dependabot, Snyk, Renovate)?
```

### Check 12.2: Outdated Packages with Security Updates

**Tools:** Code analysis
**OWASP:** A03:2025

```
WORKFLOW:
1. Compare installed versions against latest available versions
2. Identify packages with security-related changelogs
3. Check for end-of-life packages (no longer receiving security patches)

COMMANDS:
npm outdated --json 2>/dev/null
pip list --outdated --format=json 2>/dev/null
bundle outdated 2>/dev/null

CRITERIA:
- Major version behind: High risk (likely missing security fixes)
- Minor version behind with security notes: Medium risk
- Patch version behind: Low risk
- End-of-life/unmaintained package: High risk regardless of version
```

### Check 12.3: SRI (Subresource Integrity) on CDN Scripts/Styles

**Tools:** Playwright browser_evaluate
**OWASP:** A08:2025

```
PLAYWRIGHT SCRIPT:
// Evaluate in browser context
(() => {
  const scripts = document.querySelectorAll('script[src]');
  const links = document.querySelectorAll('link[rel="stylesheet"][href]');
  const results = { scripts: [], stylesheets: [], summary: {} };

  scripts.forEach(s => {
    const src = s.getAttribute('src') || '';
    const isExternal = src.startsWith('http') && !src.includes(window.location.hostname);
    if (isExternal) {
      results.scripts.push({
        src: src.substring(0, 120),
        hasIntegrity: s.hasAttribute('integrity'),
        hasCrossorigin: s.hasAttribute('crossorigin'),
        integrity: s.getAttribute('integrity') || 'MISSING'
      });
    }
  });

  links.forEach(l => {
    const href = l.getAttribute('href') || '';
    const isExternal = href.startsWith('http') && !href.includes(window.location.hostname);
    if (isExternal) {
      results.stylesheets.push({
        href: href.substring(0, 120),
        hasIntegrity: l.hasAttribute('integrity'),
        hasCrossorigin: l.hasAttribute('crossorigin'),
        integrity: l.getAttribute('integrity') || 'MISSING'
      });
    }
  });

  const total = results.scripts.length + results.stylesheets.length;
  const withSRI = [...results.scripts, ...results.stylesheets].filter(r => r.hasIntegrity).length;
  results.summary = { totalExternal: total, withSRI, withoutSRI: total - withSRI };

  return results;
})()

INDICATORS OF VULNERABILITY:
- External scripts loaded without integrity attribute
- integrity attribute present but crossorigin="anonymous" missing
- SRI hash uses weak algorithm (SHA-256 minimum, SHA-384 preferred)
```

### Check 12.4: Lock File Integrity

**Tools:** Code analysis
**OWASP:** A08:2025

```
WORKFLOW:
1. Check for existence of lock files matching the package manager
2. Verify lock files are not in .gitignore
3. Check lock file freshness (should be updated with manifest)

CHECKS:
- package.json exists -> package-lock.json or yarn.lock or pnpm-lock.yaml must exist
- requirements.txt exists -> Consider Pipfile.lock or poetry.lock
- Gemfile exists -> Gemfile.lock must exist
- go.mod exists -> go.sum must exist
- Cargo.toml exists -> Cargo.lock must exist
- composer.json exists -> composer.lock must exist

VERIFICATION:
- Run: npm ci (should succeed without modification)
- Run: pip install --require-hashes (should succeed)
- Check git log for lock file vs. manifest sync
```

### Check 12.5: Typosquatting Risk

**Tools:** Code analysis
**OWASP:** A03:2025

```
WORKFLOW:
1. Extract all dependency names from manifest files
2. Check for known typosquatting patterns
3. Verify package publisher legitimacy

KNOWN PATTERNS:
- lodash vs. lodas, lodashs, lodash-utils
- express vs. expresss, expres, express-framework
- react vs. reactt, react-native (when react-native not needed)
- Package names with extra hyphens, underscores, or character swaps
- Scoped packages impersonating unscoped (@user/lodash vs. lodash)

CHECKS:
- Compare each dependency name against known legitimate packages
- Flag packages with < 100 weekly downloads
- Flag packages with single maintainer and recent creation date
- Flag packages whose names differ by 1-2 characters from popular packages
- Check npm registry metadata: creation date, download count, maintainer history
```

### Check 12.6: CI/CD Configuration Security

**Tools:** Code analysis (Grep + Read)
**OWASP:** A08:2025

```
WORKFLOW:
1. Read all CI/CD configuration files
2. Check for secret management practices
3. Verify build reproducibility
4. Check for supply chain integrity measures

CHECKS:
a) Secrets: Are all secrets referenced via secret management (not hardcoded)?
b) Pinning: Are CI/CD actions/plugins pinned to specific versions/SHAs?
c) Permissions: Are workflow permissions minimized (least privilege)?
d) Artifacts: Are build artifacts signed or checksummed?
e) Registry: Are package registries configured securely (private registry, scoped access)?
f) Pull requests: Do PR workflows run with restricted permissions?
g) Caching: Are CI caches isolated per branch to prevent poisoning?
h) Provenance: Is SLSA provenance generated for build artifacts?
```

### Check 12.7: .env File Exposure

**Tools:** Grep + Burp
**OWASP:** A03:2025

```
TIER 0 (Code analysis):
1. Check .gitignore for .env patterns
2. Search git history for committed .env files
3. Check for .env.example with real values

TIER 1 (Burp):
1. Request common .env paths via Burp Repeater:
   - GET /.env
   - GET /.env.local
   - GET /.env.production
   - GET /.env.backup
   - GET /api/.env
   - GET /app/.env
2. Check response for environment variable format (KEY=VALUE)

INDICATORS OF VULNERABILITY:
- .env file accessible via HTTP (200 response with KEY=VALUE content)
- .env committed to git history (even if currently gitignored)
- .env.example contains real credentials instead of placeholders
```

### Check 12.8: Source Map Exposure in Production

**Tools:** Burp passive scan + Playwright
**OWASP:** A03:2025

```
PLAYWRIGHT SCRIPT:
// Check for source map references in loaded scripts
(() => {
  const scripts = document.querySelectorAll('script[src]');
  const results = [];

  scripts.forEach(s => {
    const src = s.getAttribute('src');
    if (src) {
      results.push({
        script: src.substring(0, 100),
        mapUrl: src + '.map'
      });
    }
  });

  return results;
})()

BURP WORKFLOW:
1. For each JavaScript file loaded by the application:
   a. Check response headers for SourceMap or X-SourceMap header
   b. Check last line of JS for //# sourceMappingURL= comment
   c. Request the .map URL directly
2. If .map file is accessible, check contents for original source code

INDICATORS OF VULNERABILITY:
- .map files accessible in production (200 response with JSON source map)
- SourceMap header pointing to accessible file
- sourceMappingURL comment in minified JS
```

### Check 12.9: Third-Party Script Audit

**Tools:** Playwright browser_evaluate
**OWASP:** A03:2025

```
PLAYWRIGHT SCRIPT:
// Audit all external scripts loaded at runtime
(() => {
  const observer = new PerformanceObserver(() => {});
  const entries = performance.getEntriesByType('resource');
  const scripts = entries.filter(e => e.initiatorType === 'script' || e.name.endsWith('.js'));
  const externalScripts = scripts.filter(s => !s.name.includes(window.location.hostname));

  return {
    totalScriptsLoaded: scripts.length,
    externalScripts: externalScripts.map(s => ({
      url: s.name.substring(0, 150),
      duration: Math.round(s.duration),
      transferSize: s.transferSize,
      encodedBodySize: s.encodedBodySize
    })),
    domains: [...new Set(externalScripts.map(s => new URL(s.name).hostname))]
  };
})()

CHECKS:
- Are all external domains recognized and legitimate?
- Are any scripts loaded from personal/unknown CDNs?
- Are analytics/tracking scripts from known providers?
- Do any scripts load additional scripts dynamically?
- Are any scripts served over HTTP (not HTTPS)?
```

### Check 12.10: SBOM Generation

**Tools:** Code analysis
**OWASP:** A03:2025

```
WORKFLOW:
1. Check if SBOM generation is part of the build process
2. Check for existing SBOM files (CycloneDX, SPDX format)
3. Verify SBOM completeness (direct + transitive dependencies)

CHECKS:
- Does the project generate an SBOM as part of CI/CD?
- Is the SBOM in a standard format (CycloneDX JSON/XML or SPDX)?
- Does the SBOM include transitive dependencies?
- Is the SBOM stored/published with the release artifacts?
- Are dependency licenses tracked for compliance?

FILES TO CHECK:
- bom.json, bom.xml (CycloneDX)
- *.spdx, *.spdx.json (SPDX)
- .github/workflows/*.yml (SBOM generation step)
- package.json scripts (sbom generation command)
```

---

## Tier 2: AI Judgment Questions

### Question 1: Dependency Hygiene
Does the project demonstrate active dependency management? Are there automated tools (Dependabot, Renovate, Snyk) configured? When was the last dependency update? Are there stale PRs for dependency updates?

### Question 2: Trust Boundaries
How many external domains does the application load scripts from? Are all external dependencies from well-known, reputable sources? Is there a documented policy for evaluating new dependencies?

### Question 3: Build Reproducibility
Can the application be built deterministically from the lock file? Would a fresh install produce identical artifacts? Are build tools themselves pinned to specific versions?

### Question 4: Secret Rotation
Are there mechanisms for rotating compromised credentials? How quickly could the team respond to a compromised dependency or leaked secret? Is there a documented incident response plan for supply chain attacks?

### Question 5: Defense in Depth
Even if a dependency is compromised, does the application limit the blast radius? Are dependencies sandboxed or running with least privilege? Does CSP restrict what loaded scripts can do?

### Question 6: Provenance Verification
Are package signatures verified during installation? Is there SLSA provenance for build artifacts? Are container images signed and verified?

---

## Severity Classification

### Critical (P1) -- Score: 0/10
- Direct dependency with known critical CVE (CVSS >= 9.0) actively exploited in the wild
- Committed credentials (API keys, database passwords) in current source code or recent git history
- CI/CD pipeline with hardcoded secrets and public visibility
- Compromised or typosquatted dependency actively installed

### High (P2) -- Score: 2/10
- Direct dependency with high CVE (CVSS 7.0-8.9)
- .env file accessible via HTTP in production
- Source maps exposing full source code in production
- Unpinned GitHub Actions with write permissions
- External scripts loaded without SRI from CDN
- Lock files not committed (dependency resolution not reproducible)

### Medium (P3) -- Score: 5/10
- Transitive dependency with critical/high CVE
- Outdated dependencies (major version behind) without known CVEs
- Missing Dependabot/Renovate configuration
- CI/CD permissions broader than necessary
- Missing SBOM generation

### Low (P4) -- Score: 7/10
- Minor version behind on dependencies
- Missing SRI on low-risk external resources (fonts, analytics)
- CI/CD caching without branch isolation
- No documented dependency evaluation policy
- Source maps accessible but containing only minified source

---

## False Positive Indicators

1. **Transitive CVE Not Reachable:** A CVE in a transitive dependency may not be exploitable if the vulnerable code path is never invoked by the direct dependency. Check if the vulnerable function is actually called.
2. **Development-Only Dependencies:** CVEs in devDependencies (linters, test tools, build tools) are lower risk since they do not ship to production. Verify the dependency is truly dev-only.
3. **Mitigated by Configuration:** Some CVEs require specific configuration to exploit. If the application does not use the vulnerable feature, the risk is reduced.
4. **Already Patched Downstream:** Some package managers backport security fixes without changing the major version. Check if the installed version includes the fix even if npm audit flags it.
5. **SRI Not Applicable:** Self-hosted scripts (same origin) do not need SRI. Only external CDN-hosted resources require integrity attributes.
6. **Lock File Strategy:** Some monorepo tools (Turborepo, Lerna) may use workspace-level lock files instead of per-package lock files. This is valid.

---

## Remediation

### Known CVE Dependencies
- Run `npm audit fix` or `pip-audit --fix` for automatic patching
- For breaking changes: Create upgrade plan with testing timeline
- Set up automated dependency monitoring (Dependabot, Snyk, Renovate)
- Enable `npm audit` as CI/CD gate (fail build on critical/high CVEs)
- Pin direct dependencies to exact versions in production applications

### SRI Implementation
```html
<!-- Add integrity and crossorigin attributes to all CDN scripts -->
<script
  src="https://cdn.example.com/library.min.js"
  integrity="sha384-oqVuAfXRKap7fdgcCY5uykM6+R9GqQ8K/uxy9rx7HNQlGYl1kPzQho1wx4JwY8w"
  crossorigin="anonymous">
</script>
```
- Generate SRI hashes: `openssl dgst -sha384 -binary file.js | openssl base64 -A`
- Use SRI Hash Generator tools for CDN resources
- Add `require-sri-for script style` to CSP (deprecated but informational)

### Lock File Integrity
- Commit all lock files to version control
- Use `npm ci` (not `npm install`) in CI/CD pipelines
- Enable `--frozen-lockfile` flag in yarn/pnpm
- Set up pre-commit hook to verify lock file consistency

### CI/CD Hardening
- Pin all GitHub Actions to full commit SHA
- Use `permissions:` block with least-privilege in GitHub Actions
- Store all secrets in GitHub Secrets / Vault / KMS
- Use `pull_request` event (not `pull_request_target`) for PR workflows
- Enable branch protection with required status checks

### Secret Management
- Rotate any compromised credentials immediately
- Use git-secrets or truffleHog as pre-commit hooks
- Implement secret scanning in CI/CD pipeline
- Use environment-specific secret stores (AWS Secrets Manager, HashiCorp Vault)
- Never commit .env files -- use .env.example with placeholder values

### Source Map Protection
- Remove sourceMappingURL comments in production builds
- Configure build tool to skip source map generation for production
- If source maps are needed for error tracking, upload them to error tracking service (Sentry) and do not serve publicly
- Block .map file access at the web server/CDN level
