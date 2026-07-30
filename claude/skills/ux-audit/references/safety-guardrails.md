# Safety Guardrails for --fix Mode

## Purpose

These guardrails prevent the UX audit auto-fix system from modifying any code that affects application behavior, data flow, or business logic. The fix mode is restricted to **visual and presentational changes only**.

---

## NEVER-MODIFY LIST

The following code constructs must NEVER be altered by auto-fix, regardless of context.

### 1. Event Handlers
`onClick`, `onSubmit`, `onChange`, `onMouseEnter`, `onMouseLeave`, `onKeyDown`, `onFocus`, `onBlur`, `onInput`, `onScroll`, `onDrag`, `onDrop`, `onTouchStart`, `addEventListener`

**Why:** Event handlers contain application logic that responds to user interaction. Changing them can break functionality, create security holes, or alter user flows.

### 2. State Management
`useState`, `useEffect`, `useLayoutEffect`, `useContext`, `useReducer`, `useSyncExternalStore`, Redux (`dispatch`, `useSelector`, `createSlice`, `configureStore`), Zustand (`create`, `useStore`), Jotai (`atom`, `useAtom`), Recoil (`atom`, `selector`), MobX (`observable`, `action`), Valtio (`proxy`, `useSnapshot`), `setState`, `this.state`

**Why:** State drives the entire application. Modifying state declarations, updates, or subscriptions can cause data loss, infinite loops, race conditions, or silent corruption.

### 3. API Calls
`fetch()`, `axios`, `useSWR`, `useQuery`, `useMutation`, `createAsyncThunk`, `XMLHttpRequest`, `graphql`, `gql`, WebSocket connections, Server-Sent Events, `trpc`

**Why:** API calls handle data exchange with backends. Altering them can break data integrity, authentication flows, or cause unintended data mutations.

### 4. Routing
`next/router`, `next/navigation`, `useRouter`, `usePathname`, `useSearchParams`, `react-router` (`Route`, `Link`, `Navigate`, `useNavigate`, `useParams`), `href` with dynamic values, `window.location`, `history.pushState`, `redirect()`, `permanentRedirect()`

**Why:** Routing controls navigation and URL state. Changes can break deep links, cause redirect loops, or expose unauthorized pages.

### 5. Form Submissions
`action` attributes, `method` attributes, form handling logic, `FormData`, `useFormState`, `useFormStatus`, server actions tied to forms, validation logic (`Zod`, `Yup`, `Joi` schemas)

**Why:** Form submission logic controls data validation and server communication. Alterations can bypass validation, corrupt submitted data, or break form flows.

### 6. Hooks
Custom hooks (`use*` functions), `useCallback`, `useMemo`, `useRef`, `useImperativeHandle`, `useId`, `useDeferredValue`, `useTransition`, `useOptimistic`

**Why:** Hooks encapsulate reusable logic, performance optimizations, and imperative references. Modifying them can cause stale closures, memory leaks, or break component contracts.

### 7. Props / Data Flow
Component props (the entire props interface/type), prop drilling chains, context providers (`createContext`, `Provider`, `value=`), render props, children manipulation (`React.Children`, `cloneElement`)

**Why:** Props and context form the data contract between components. Changing them breaks parent-child communication and can cascade failures through the component tree.

### 8. Conditional Rendering
Ternary operators deciding what renders (`condition ? <A/> : <B/>`), `&&` chains for conditional display, `switch` statements for UI logic, early returns based on state/props, error boundaries

**Why:** Conditional rendering controls what users see based on application state. Modifying these changes feature visibility, breaks feature flags, and can expose incomplete UI.

### 9. Authentication Logic
Auth checks (`isAuthenticated`, `session`, `user`), route guards, middleware auth logic, token handling (`JWT`, `cookies`, `localStorage` for auth), role-based access control, `getServerSession`, `auth()`, `currentUser()`

**Why:** Authentication logic protects user data and access control. Any modification risks exposing protected routes, leaking user data, or locking users out.

### 10. Environment Variables
`process.env.*`, `import.meta.env.*`, `NEXT_PUBLIC_*`, `.env` file references, runtime configuration

**Why:** Environment variables control deployment-specific behavior (API URLs, feature flags, secrets). Changing references can expose secrets or point to wrong environments.

### 11. Build Configuration
`next.config.js/ts/mjs`, `vite.config.ts`, `tsconfig.json`, `tailwind.config.ts/js`, `postcss.config.js`, `webpack.config.js`, `babel.config.js`, `eslint.config.*`, `package.json` (scripts, dependencies)

**Why:** Build config changes affect the entire application compilation, bundling, and deployment pipeline. A single misconfiguration can break the build or introduce vulnerabilities.

### 12. Server Components
`'use server'` directive, server actions, `generateMetadata`, `generateStaticParams`, server-only imports, `cookies()`, `headers()`, `revalidatePath`, `revalidateTag`

**Why:** Server components run on the server with elevated privileges. Modifications can expose server-side secrets, break SSR/SSG, or create security vulnerabilities.

### 13. Database Queries
Prisma (`prisma.*.find*`, `prisma.*.create`, `prisma.*.update`, `prisma.*.delete`), Drizzle (`db.select()`, `db.insert()`, `db.update()`, `db.delete()`), raw SQL, Knex, Sequelize, TypeORM, Mongoose, any ORM method calls

**Why:** Database queries directly modify persistent data. Any change risks data corruption, data loss, SQL injection, or unauthorized data access.

### 14. Third-Party Integrations
Analytics SDKs (`gtag`, `posthog`, `mixpanel`, `segment`), payment processing (`stripe`, `paypal`, `braintree`), chat widgets (`intercom`, `drift`, `crisp`), MCP tool calls, email services (`sendgrid`, `resend`, `postmark`), monitoring (`sentry`, `datadog`, `newrelic`)

**Why:** Third-party integrations handle billing, compliance tracking, and external communication. Modifications can break revenue collection, compliance auditing, or customer support.

---

## SAFE-TO-MODIFY LIST

The following constructs are safe for auto-fix to modify.

### CSS Classes
```jsx
// Changing Tailwind classes
className="text-sm text-gray-500"  →  className="text-base text-gray-700"

// Changing CSS module classes
className={styles.header}  →  className={styles.headerUpdated}
```

### CSS Custom Properties
```css
/* Adjusting design tokens */
--spacing-unit: 4px;  →  --spacing-unit: 8px;
--color-primary: #3b82f6;  →  --color-primary: #2563eb;
```

### Static Text
```jsx
// Updating labels, headings, descriptions
<h1>Welcome</h1>  →  <h1>Welcome to Our Platform</h1>
<p>Click here</p>  →  <p>Get started</p>
```

### HTML Attributes (non-behavioral)
```jsx
// Accessibility attributes
aria-label="close"  →  aria-label="Close dialog"
alt=""  →  alt="Company logo"
title="info"  →  title="More information"
role="presentation"  →  role="img"
tabindex="-1"  →  tabindex="0"
```

### CSS Files
```css
/* Any property in .css, .scss, .module.css files */
.container { padding: 12px; }  →  .container { padding: 16px; }
.button { border-radius: 4px; }  →  .button { border-radius: 8px; }
```

### Tailwind Classes
```jsx
// Utility class changes
className="p-2 m-1 rounded"  →  className="p-4 m-2 rounded-lg"
className="flex row"  →  className="flex flex-col"
```

### SVG Attributes
```jsx
// Visual SVG properties only
<svg width="16" height="16" fill="currentColor" stroke="none">
// Safe: width, height, fill, stroke, viewBox, strokeWidth, opacity
```

### CSS Animations
```css
/* Keyframe and transition changes */
transition: all 0.2s;  →  transition: opacity 0.3s ease;
animation: fade 1s;  →  animation: fadeIn 0.5s ease-in;
```

### Semantic HTML Tags
```jsx
// Improving semantic structure
<div class="nav">  →  <nav>
<div class="footer">  →  <footer>
<div class="article">  →  <article>
```

---

## PRE-FLIGHT VALIDATION CHECKLIST

Before applying ANY modification, the auto-fix system must complete all 5 steps:

### Step 1: Scope Check
- [ ] Read the target file completely
- [ ] Identify every export and import in the file
- [ ] Confirm the modification touches ONLY items on the SAFE-TO-MODIFY list

### Step 2: Dependency Trace
- [ ] Search for all files that import from the target file
- [ ] Verify no downstream component depends on the specific value being changed
- [ ] For className changes: confirm no JS code references the class name for logic (e.g., `document.querySelector('.old-class')`)

### Step 3: Behavioral Isolation
- [ ] Confirm the changed line contains NO event handler, state reference, or conditional logic
- [ ] Confirm the changed line is not inside a function that returns data (vs. JSX)
- [ ] Confirm no NEVER-MODIFY item exists on the same line or expression

### Step 4: Reversibility Confirmation
- [ ] The change can be undone with a single `git checkout` of the file
- [ ] The change does not require database migrations, env var updates, or config changes
- [ ] The change does not alter any test assertions or snapshots

### Step 5: Dry-Run Validation
- [ ] Generate the exact diff before applying
- [ ] Log the diff to the audit report with the finding ID
- [ ] Confirm the diff changes fewer than 5 lines per finding (if more, escalate)

---

## ESCALATION TEMPLATE

When a fix is identified but too risky for auto-application, output this template instead of modifying the file:

```markdown
## ESCALATION: Manual Fix Required

**Finding ID:** [FINDING-ID]
**Severity:** [Critical/High/Medium/Low]
**File:** [file/path:line]
**Pass:** [Which audit pass identified this]

### What Needs to Change
[Describe the visual/UX issue]

### Why Auto-Fix Cannot Apply
[Specific reason from NEVER-MODIFY list, e.g., "The className is on the same JSX element as an onClick handler that conditionally renders based on auth state"]

### Recommended Manual Fix
```diff
- [current code]
+ [proposed code]
```

### Risk Assessment
- **Behavioral impact:** [None expected / Possible side effect description]
- **Files affected:** [List of files importing this component]
- **Test coverage:** [Covered by tests? Which ones?]

### Verification Steps
1. [Step to verify the fix works]
2. [Step to verify no behavior changed]
3. [Step to verify accessibility maintained]
```

---

## Summary Rules

1. **When in doubt, escalate.** A false negative (missed fix) is always better than a broken app.
2. **One finding, one fix.** Never batch multiple changes into a single edit operation.
3. **Log everything.** Every modification and every skip must appear in the audit report.
4. **Preserve formatting.** Match the existing file's indentation, quote style, and line endings.
5. **Never add dependencies.** Auto-fix must not install packages, add imports, or create files.
