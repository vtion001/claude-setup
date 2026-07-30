# QA Audit Checklist — Per-Page-Type Checks

## Universal Checks (Every Page)

### Visual
- [ ] Page loads without blank/white screen
- [ ] No broken images (check all `<img>` elements)
- [ ] Logo renders correctly in navigation/sidebar
- [ ] Navigation links are all clickable and route correctly
- [ ] No horizontal scroll overflow on desktop viewport
- [ ] Text is readable (no overlapping, no truncation of critical info)
- [ ] Icons render (no missing font-awesome/heroicons placeholders)
- [ ] Active page is highlighted in navigation
- [ ] Page title/heading matches the route context

### Console & Network
- [ ] No JavaScript errors in console
- [ ] No failed network requests (4xx, 5xx)
- [ ] No mixed content warnings (HTTP resources on HTTPS page)
- [ ] No CORS errors

### Responsiveness
- [ ] Page renders without breaking at 1920px (desktop)
- [ ] Page renders without breaking at 1024px (tablet)
- [ ] Page renders without breaking at 375px (mobile)
- [ ] Navigation collapses or adapts on mobile

### Accessibility
- [ ] All images have alt text
- [ ] Form inputs have associated labels
- [ ] Buttons have discernible text
- [ ] Color contrast meets WCAG AA (4.5:1 for text)
- [ ] Focus indicators are visible on interactive elements

---

## Dashboard Pages

### Data Integrity
- [ ] All metric cards show non-zero values (or explain why zero)
- [ ] Metrics are scoped to the correct team/group/account
- [ ] Metric labels accurately describe what they measure
- [ ] Total counts are internally consistent (e.g., Inbound + Outbound = Total)
- [ ] Percentage values are between 0-100%
- [ ] Charts render with data (not empty)
- [ ] Chart axes are labeled
- [ ] Date range filter affects all widgets consistently

### Layout
- [ ] Metric cards are evenly spaced and aligned
- [ ] Charts don't overlap other elements
- [ ] Loading states show spinners/skeletons (not blank)

---

## Table/List Pages (Calls, Agents, Logs)

### Data Display
- [ ] Table has data (not perpetually empty)
- [ ] Column headers are descriptive
- [ ] Numeric columns are right-aligned
- [ ] Date columns show human-readable format
- [ ] Duration values have correct units (and unit is labeled)
- [ ] Status/badge colors are meaningful and consistent
- [ ] Empty state shows a helpful message (not just blank table)

### Pagination
- [ ] Pagination exists for tables with >20 rows
- [ ] Page size is reasonable (10-25 per page)
- [ ] Pagination controls work (next, previous, page numbers)
- [ ] Total count is shown (e.g., "Showing 1-20 of 178")
- [ ] Changing page doesn't reset filters

### Sorting
- [ ] At least one column is sortable
- [ ] Sort direction is indicated visually
- [ ] Default sort makes sense (usually most recent first)

### Filtering
- [ ] Filter controls are present above the table
- [ ] Filters produce correct results
- [ ] Clearing filters resets to unfiltered view
- [ ] Filters persist across pagination
- [ ] No filter combination produces an error

---

## Filter Components

### Date Range Pickers
- [ ] Cannot select future dates (max = today)
- [ ] "From" date cannot be after "To" date
- [ ] Changing "From" updates "To" minimum constraint
- [ ] Default range is reasonable (e.g., last 7 or 30 days)
- [ ] Clear/reset button exists

### Dropdown Selects
- [ ] Dropdowns are populated (not empty)
- [ ] Dependent dropdowns update reactively (e.g., agent list filters when team changes)
- [ ] "All" option exists where appropriate
- [ ] Selected value persists after search/filter
- [ ] Values match what appears in the data table

### Text Inputs
- [ ] Placeholder text describes expected input
- [ ] Input type matches data type (number, email, tel, date)
- [ ] Fields that should be enums are NOT free-text
- [ ] Search inputs have debounce or submit button (don't fire on every keystroke)

---

## Detail/Show Pages (Call Detail, Agent Profile)

### Content
- [ ] All expected fields are populated
- [ ] Related data sections load (transcripts, scores, history)
- [ ] Back/return navigation works
- [ ] Breadcrumbs or page title shows context

### Actions
- [ ] Action buttons are present (Transcribe, Analyze, etc.)
- [ ] Buttons are role-gated (hidden for unauthorized users)
- [ ] Clicking actions produces expected results
- [ ] Loading/progress indicators appear during long operations
- [ ] Success/error feedback after actions

---

## Form Pages (Settings, User Management)

### Validation
- [ ] Required fields are marked
- [ ] Submitting empty required fields shows validation errors
- [ ] Validation messages are clear and positioned near the field
- [ ] Invalid input types are rejected (e.g., letters in phone field)

### Submission
- [ ] Form submits successfully with valid data
- [ ] Success confirmation is shown
- [ ] Data persists after page reload
- [ ] Cancel/back button doesn't lose unsaved changes without warning

---

## Auth Pages (Login, Register, Forgot Password)

### Login
- [ ] Login form renders correctly
- [ ] Valid credentials succeed and redirect to dashboard
- [ ] Invalid credentials show clear error message
- [ ] Password field masks input
- [ ] "Remember me" checkbox works (if present)
- [ ] Login is rate-limited (try wrong password 5+ times)

### Session
- [ ] Logged-in state persists across page reloads
- [ ] Logout clears session and redirects to login
- [ ] Protected pages redirect to login when unauthenticated
- [ ] Session timeout works as expected

---

## Summary Counter vs. Table Cross-Check

This check applies to any page with both summary cards/counters AND a data table:

1. Count total rows in the table (across all pages if paginated)
2. Compare against each summary counter
3. Verify: Sum of category counters = Total counter
4. Verify: Category breakdown percentages add up to ~100%
5. If counters and table disagree, flag as **High severity** data integrity issue

---

## Performance Baselines

| Metric | Acceptable | Needs Attention | Critical |
|--------|-----------|-----------------|----------|
| Page load time | < 2s | 2-5s | > 5s |
| Time to interactive | < 3s | 3-7s | > 7s |
| DOM nodes | < 1500 | 1500-3000 | > 3000 |
| Network requests | < 30 | 30-60 | > 60 |
| JavaScript errors | 0 | 1-2 | > 2 |
| Failed requests | 0 | 1 | > 1 |
