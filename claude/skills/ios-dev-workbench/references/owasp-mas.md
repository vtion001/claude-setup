# OWASP MAS Control IDs Reference

Used by `/ios-security-audit`. June 2025 refresh.

## MASVS Control Groups
- **MASVS-STORAGE** — Local storage
- **MASVS-CRYPTO** — Cryptography
- **MASVS-AUTH** — Authentication & session management
- **MASVS-NETWORK** — Network communication
- **MASVS-PLATFORM** — Platform interaction
- **MASVS-CODE** — Code quality + build settings
- **MASVS-RESILIENCE** — Resilience against reverse engineering (L2 only)
- **MASVS-PRIVACY** — Privacy controls

## MASTG (testing guide) per group

### Storage (MSTG-STORAGE-1 to 14)
1. System credential storage facilities are used appropriately
2. No sensitive data in local storage
3. No sensitive data in logs
4. No sensitive data in 3rd-party stores (e.g. SDK caches)
5. Keyboard cache is disabled on sensitive inputs
6. No sensitive data in IPC mechanisms
7. No sensitive data in UI (screenshots, snapshots)
8. No sensitive data in backups
9. App removes sensitive data on logout
10. App educates user on sensitive-data risks
11. Backup ATS settings are correct
12. Pasteboard isn't used for sensitive data
13. No sensitive data in error messages
14. No sensitive data in HTTP request/response bodies (when logged)

### Cryptography (MSTG-CRYPTO-1 to 6)
1. App doesn't rely on symmetric crypto with hardcoded keys
2. App uses proven cryptographic implementations
3. App uses crypto according to industry best practices
4. App doesn't use deprecated / broken cryptographic algorithms
5. App doesn't reuse the same key for multiple purposes
6. All random values are generated using a sufficiently secure RNG

### Auth (MSTG-AUTH-1 to 12)
1. Server-side authentication; client-only auth is not considered secure
2. Stateless auth uses signed tokens (JWT, etc.)
3. App uses appropriate session management
4. Sessions invalidate on logout
5. Password policy exists + is enforced
6. App lockout after multiple failed logins
7. Sensitive Keychain entries require biometric / passcode
8. Biometric auth uses keychain integration
9. ...

### Network (MSTG-NETWORK-1 to 6)
1. All network traffic uses TLS/HTTPS
2. TLS settings follow current best practices
3. Cert pinning where appropriate
4. App verifies X.509 chain
5. App doesn't rely solely on URL allowlisting for security
6. App detects + handles network attacks

### Platform (MSTG-PLATFORM-1 to 11)
1. App permissions are minimum-necessary
2. All IPC inputs validated
3. WebView doesn't expose unnecessary native APIs
4. WebView prevents loading of arbitrary URLs
5. JS is disabled in WebView when not needed
6. Sensitive UI hidden in app switcher
7. App doesn't expose sensitive functionality via URL schemes / Universal Links
8. ...

### Code (MSTG-CODE-1 to 9)
1. App is signed and provisioned correctly
2. App is built in release mode with appropriate settings
3. Debug symbols stripped
4. Debugging code removed
5. All 3rd-party libs are identified and have no known CVEs
6. App checks for compromised env (jailbreak detection) — L2 only
7. Free-from injection points (SQL/XSS/etc.)
8. Native input handling is safe
9. ...

### Resilience (MSTG-RESILIENCE-1 to 13) — L2 only
1. App detects rooted/jailbroken environment
2. App detects + responds to debugger
3. App detects + responds to tampering
4. App detects + responds to reverse engineering
5. App detects emulation
6. ...

## Reference

- **MASVS** — https://mas.owasp.org/MASVS/
- **MASTG** — https://mas.owasp.org/MASTG/
- **MAS Checklist** — https://mas.owasp.org/checklists/
