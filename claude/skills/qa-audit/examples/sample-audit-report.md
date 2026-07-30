# QA Audit Report -- BOB-AGS

**Date:** 2026-05-19
**URL:** http://localhost:8082
**Branch:** stt-engine
**Commit:** ca10a0b
**Auditor:** Claude QA Audit Skill

---

## Executive Summary

| Metric | Value |
|--------|-------|
| Pages Audited | 8 |
| Total Issues Found | 3 |
| Critical | 0 |
| High | 1 |
| Medium | 2 |
| Low | 0 |
| Screenshots Taken | 10 |

### Top Findings
1. Dashboard shows all-account data instead of Phillies-scoped metrics
2. Broken logo image in sidebar navigation
3. Date range picker allows future date selection

---

## Pages Audited

| # | Page | Route | Status | Issues |
|---|------|-------|--------|--------|
| 1 | Login | `/login` | Pass | 0 |
| 2 | Dashboard | `/dashboard` | Fail | 1 |
| 3 | Calls | `/calls` | Pass | 0 |
| 4 | QA Logs | `/qa` | Pass | 0 |
| 5 | Agents | `/agents` | Pass | 0 |
| 6 | Sidebar (global) | all pages | Fail | 1 |
| 7 | Date Picker (global) | all pages | Fail | 1 |
| 8 | Live Monitoring | `/live-monitoring` | Pass | 0 |

---

## Findings

### FINDING-001: Dashboard displays all-account data instead of Phillies-scoped metrics

**Severity:** High
**Page:** Dashboard (`/dashboard`)
**Category:** Data Integrity

**Screenshot:**
![Dashboard showing all-account totals](./qa-audit-screenshots/dashboard_unscoped-data_20260519.png)

**Problem:**
The dashboard metric cards show Total Calls: 122,778 across all agents and groups. The numbers reflect the entire CTM account rather than the Phillies agent group, making the dashboard metrics misleading for Phillies supervisors.

**Expected Behavior:**
All dashboard metrics should be scoped to the Phillies agent group only. A visible label should indicate the active scope (e.g., "Showing data for: Phillies").

**Root Cause:**
The `DashboardController@index` method calls `CTMCallService::getCallMetrics()` without passing a group filter. The CTM API returns all data when no group constraint is applied.

**Files Affected:**
- `app/Http/Controllers/DashboardController.php:42` -- missing group filter parameter in metrics query
- `app/Services/CTMCallService.php:87` -- `getCallMetrics()` accepts but does not enforce group scope

**Suggested Fix:**
```php
// Before (DashboardController.php:42)
$metrics = $this->ctmCallService->getCallMetrics($from, $to);

// After
$metrics = $this->ctmCallService->getCallMetrics($from, $to, group: 'phillies');
```

**Verification Steps:**
1. Reload dashboard after fix
2. Confirm Total Calls is significantly lower than 122,778
3. Cross-reference a known Phillies agent's call count against dashboard total

**Linear Issue:** [ALL-125](https://linear.app/allianceglobalsolutions/issue/ALL-125)

---

### FINDING-002: Broken logo image in sidebar

**Severity:** Medium
**Page:** All pages (sidebar component)
**Category:** Visual

**Screenshot:**
![Broken image icon in sidebar](./qa-audit-screenshots/sidebar_broken-logo_20260519.png)

**Problem:**
The sidebar displays a broken image placeholder with alt text "BOB Logo" instead of the company logo. The `src` path cannot be resolved by the browser.

**Expected Behavior:**
The BOB-AGS logo should render correctly in the sidebar on all pages.

**Root Cause:**
The `<img>` tag in the navigation layout references a path that does not resolve through Vite's asset pipeline. The logo file exists at `public/images/bob-logo.png` but the src uses a relative path instead of the `asset()` helper.

**Files Affected:**
- `resources/views/layouts/navigation.blade.php:12` -- incorrect `src` attribute

**Suggested Fix:**
```blade
{{-- Before --}}
<img src="/images/bob-logo.png" alt="BOB Logo">

{{-- After --}}
<img src="{{ asset('images/bob-logo.png') }}" alt="BOB Logo">
```

**Verification Steps:**
1. Reload any page
2. Confirm the logo renders in the sidebar without broken image icon

**Linear Issue:** [ALL-119](https://linear.app/allianceglobalsolutions/issue/ALL-119)

---

### FINDING-003: Date range picker allows invalid date selection

**Severity:** Medium
**Page:** Dashboard, Calls, QA Logs (shared component)
**Category:** Form/Filter Validation

**Screenshot:**
![Date picker showing future date selected](./qa-audit-screenshots/dashboard_future-date_20260519.png)

**Problem:**
The From and To date inputs allow selecting future dates and inverted ranges (From > To). This produces empty or incorrect results without user feedback.

**Expected Behavior:**
Both date inputs should cap at today's date. The To input should enforce a minimum of the From date.

**Root Cause:**
The `<input type="date">` elements do not set `max` or `min` attributes. No cross-field validation exists.

**Files Affected:**
- `resources/views/dashboard.blade.php:67` -- missing `max` attribute on date inputs
- `resources/views/calls/index.blade.php:45` -- same issue on calls page

**Suggested Fix:**
```blade
{{-- Before --}}
<input type="date" x-model="from">
<input type="date" x-model="to">

{{-- After --}}
<input type="date" x-model="from" max="{{ now()->format('Y-m-d') }}">
<input type="date" x-model="to" :min="from" max="{{ now()->format('Y-m-d') }}">
```

**Verification Steps:**
1. Open date picker -- confirm no future dates are selectable
2. Set a From date, open To picker -- confirm dates before From are disabled

**Linear Issue:** [ALL-121](https://linear.app/allianceglobalsolutions/issue/ALL-121)

---

## Pages With No Issues

| Page | Route | Screenshot |
|------|-------|------------|
| Login | `/login` | `login_baseline_20260519.png` |
| Calls | `/calls` | `calls_baseline_20260519.png` |
| QA Logs | `/qa` | `qa-logs_baseline_20260519.png` |
| Agents | `/agents` | `agents_baseline_20260519.png` |
| Live Monitoring | `/live-monitoring` | `live-monitoring_baseline_20260519.png` |

---

## Audit Configuration

| Setting | Value |
|---------|-------|
| App URL | http://localhost:8082 |
| Auth Method | Session (Laravel Breeze) |
| Test User | dev.admin@bob-ags.local |
| Browser | Chromium (Playwright) |
| Viewport | 1920x1080 |
| Routes Discovered | 12 |
| Routes Skipped | 4 (API/webhook) |

---

## Recommendations

### Immediate (fix before next deploy)
1. FINDING-001: Dashboard Phillies scoping -- supervisors are seeing wrong metrics

### Short-term (this sprint)
1. FINDING-002: Broken sidebar logo -- affects perceived quality
2. FINDING-003: Date picker validation -- prevents invalid queries

### Backlog
- None from this audit

---

*Generated by Claude QA Audit Skill v1.0.0*
