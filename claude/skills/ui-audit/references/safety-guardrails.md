# Safety Guardrails for --fix Mode

## Golden Rule

**When in doubt, don't fix -- report.**

Auto-fix mode exists to handle low-risk, purely presentational changes. If a modification has any chance of altering behavior, event flow, data rendering, or application state, it MUST be escalated to the report as a manual fix recommendation. The cost of a broken UI is always higher than the cost of a manual review.

---

## Never-Modify List

These 14 categories are strictly off-limits for auto-fix. If the target line or its immediate context (5 lines above/below) touches any of these, ESCALATE.

### 1. Event Handlers
`onClick`, `onSubmit`, `onChange`, `onMouseEnter`, `onMouseLeave`, `onKeyDown`, `onFocus`, `onBlur`, `addEventListener`, `removeEventListener`, custom event dispatchers.

### 2. State Management
`useState`, `useEffect`, `useLayoutEffect`, `useContext`, `useReducer`, `useSyncExternalStore`, Redux (`dispatch`, `useSelector`, `createSlice`), Zustand (`create`, `useStore`), Jotai (`atom`, `useAtom`), signals, `setState`, reactive stores.

### 3. API Calls
`fetch()`, `axios`, `useSWR`, `useQuery`, `useMutation`, `getServerSideProps`, `getStaticProps`, server actions (`'use server'`), `trpc`, GraphQL queries/mutations.

### 4. Routing
`next/router`, `next/navigation`, `useRouter`, `usePathname`, `useSearchParams`, `react-router` (`Route`, `Navigate`, `useNavigate`), `Link` components, dynamic route segments `[slug]`.

### 5. Form Submissions
`action` attributes, `method` attributes, `FormData`, `handleSubmit`, `onSubmit`, `useFormState`, `useFormStatus`, form validation logic, `Zod`/`Yup` schemas tied to forms.

### 6. Hooks
Custom hooks (`use*`), `useCallback`, `useMemo`, `useRef`, `useId`, `useImperativeHandle`, `useTransition`, `useDeferredValue`, `useOptimistic`.

### 7. Props / Data Flow
Component props (adding, removing, renaming), context providers (`Provider value={}`), prop drilling chains, render props, children manipulation, `cloneElement`.

### 8. Conditional Rendering
Ternary operators rendering different components, `&&` chains, `switch` statements for UI logic, `if/else` blocks that control what renders, `.map()` with conditional returns.

### 9. Authentication Logic
Auth checks (`isAuthenticated`, `session`), route guards, middleware auth, `useSession`, `getSession`, `signIn`/`signOut`, JWT handling, role-based access control.

### 10. Environment Variables
`process.env.*`, `import.meta.env.*`, `NEXT_PUBLIC_*`, `.env` file values, runtime config objects.

### 11. Build Configuration
`next.config.js/ts/mjs`, `vite.config.*`, `webpack.config.*`, `tsconfig.json`, `postcss.config.*`, `tailwind.config.*`, `eslint.config.*`.

### 12. Server Components
`'use server'` directive, server actions, `getServerSideProps`, `getStaticProps`, `generateStaticParams`, `generateMetadata`, Next.js loaders, RSC boundaries.

### 13. Database Queries
Prisma (`prisma.*.findMany`, `prisma.*.create`), Drizzle, raw SQL, ORM calls, data fetching functions, repository patterns, `db.*` calls.

### 14. Third-Party Integrations
Analytics (`gtag`, `posthog`, `mixpanel`), payment SDKs (`stripe`, `paypal`), chat widgets (`intercom`, `crisp`), MCP tool calls, external SDK initializations, webhook handlers.

---

## Safe-to-Modify List

These changes are purely presentational and carry no behavioral risk when applied correctly.

### 1. CSS Classes
Tailwind utilities, CSS module classnames. Example: `p-2` to `p-4`, `text-gray-500` to `text-gray-600`.

### 2. CSS Custom Properties
`--color-*`, `--spacing-*`, `--font-*` token values. Example: `--color-primary: #3b82f6` to `--color-primary: #2563eb`.

### 3. Static Text Content
Headings, labels, button text, placeholder text, `aria-label` values. NOT interpolated strings or template literals with variables.

### 4. HTML Attributes
`aria-label`, `aria-describedby`, `alt`, `title`, `role`, `tabindex`, `data-testid`, `lang`, `dir`.

### 5. CSS Files
`.css`, `.scss`, `.module.css` -- style rules only. Never modify JS-in-CSS expressions, CSS-in-JS runtime logic, or `composes` statements that affect component logic.

### 6. Tailwind Class Swaps
Utility replacements: `text-sm` to `text-base`, `gap-2` to `gap-4`, `rounded` to `rounded-lg`, `hidden` to `block` (layout-only, not conditional visibility).

### 7. SVG Attributes
`viewBox`, `fill`, `stroke`, `stroke-width`, `width`, `height`. NOT event handlers on SVG elements, NOT `<use>` href changes.

### 8. CSS Animations
`@keyframes` definitions, `transition` properties, `animation-duration`, `animation-timing-function`, `animation-delay`.

### 9. Semantic HTML Tags
`div` to `section`, `div` to `nav`, `div` to `article`, `span` to `label`, `div` to `main`. Structure-only changes -- no logic change, no prop change.

### 10. CSS Variable Definitions
Adding or modifying token values in `:root`, `[data-theme]`, or theme configuration files. Token value changes only, not token consumption logic.

---

## Pre-Flight Validation

Before modifying ANY file, execute this 5-step checklist. If any step fails, ESCALATE to report-only.

### Step 1: Read the Full Target File
Read the complete file to understand its full context. Never modify a file you have only partially read. Understand what the component does, what it imports, and what it exports.

### Step 2: Trace Imports
If the file imports from API, data, state, auth, or server layers -- ESCALATE. Check for:
- `import` from `@/lib/api`, `@/services`, `@/store`, `@/hooks` (custom), `@/auth`
- `import` from `next/navigation`, `next/headers`, server action files
- Any import that suggests the file has side effects beyond rendering

### Step 3: Check Event Handler Proximity
Examine 5 lines above and 5 lines below the modification zone. If any event handler, state setter, or side-effect call exists in that range -- ESCALATE. The risk of accidentally breaking handler binding or closure scope is too high.

### Step 4: Verify Purely Presentational
The change must be visual-only. Ask: "If I revert this change, will the application behave identically?" If the answer is no or uncertain -- ESCALATE.

### Step 5: Dry-Run Validation
Mentally apply the change. Verify:
- No syntax errors introduced (unclosed tags, missing quotes, broken JSX)
- No layout shifts that could break functionality (removing a container that holds interactive elements)
- No accessibility regressions (removing aria attributes, breaking label associations)
- No class name conflicts or specificity issues

---

## Escalation Template

When a fix is too risky for auto-application, include this in the report:

```
**MANUAL FIX REQUIRED**
- Finding: [description of the issue]
- File: [absolute/path/to/file:line_number]
- Recommended change: [specific change with before/after]
- Why auto-fix was skipped: [reason -- e.g., "event handler within 3 lines of target", "file imports from API layer", "conditional rendering logic adjacent"]
- Risk level: [Low / Medium / High]
```

Always err on the side of escalation. A developer reviewing a clear recommendation is faster than debugging a broken auto-fix.

---

## Post-Fix Verification

After applying any auto-fix, perform these checks:

1. **Re-run the affected Tier 1 check** to verify the score improved or the finding resolved
2. **Take before/after screenshots** using Playwright to confirm visual correctness
3. **Verify no console errors** were introduced by evaluating `window.__console_errors` or checking the browser console
4. **Check for layout shifts** -- compare element positions before and after to ensure nothing moved unexpectedly
5. **Confirm no new findings** were introduced by the fix itself (e.g., fixing a color token but introducing a contrast issue)

If any verification step fails, **revert the change immediately** and escalate to the report as a manual fix.
