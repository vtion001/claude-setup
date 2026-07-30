---
name: on-boarding-generator
description: Build a first-run animated guided tour (spotlight coachmarks) + in-app Help Center for a Vue 3 + Laravel SPA. Covers backend onboarded_at flag, useTour composable, GuidedTour spotlight component, data-tour anchor convention, and HelpView content structure.
---

# Onboarding Generator Skill

Build a complete first-run onboarding system: animated guided tour with spotlight coachmarks and a searchable in-app Help Center. Pattern extracted from the AGS Email Tool implementation (PR #42).

## What Gets Built

1. **Backend** — Per-user `onboarded_at` nullable timestamp; `POST /api/onboarding/complete` route
2. **Guided Tour** — Spotlight overlay with CSS transition glide between steps; keyboard nav; auto-start on first login; replay from Profile
3. **Help Center** — `/help` route; two-pane search + reader; articles as trusted HTML; `searchArticles()` filter

---

## Phase 1: Backend — Per-User Onboarding Flag

### Migration
`database/migrations/<timestamp>_add_onboarded_at_to_users_table.php`
```php
public function up(): void
{
    Schema::table('users', function (Blueprint $table) {
        $table->timestamp('onboarded_at')->nullable()->after('remember_token');
    });
}
public function down(): void
{
    Schema::table('users', function (Blueprint $table) {
        $table->dropColumn('onboarded_at');
    });
}
```

### Model — User.php
Add to `$casts`:
```php
'onboarded_at' => 'datetime',
```

### AuthController — user payload helper + endpoint
```php
private function userPayload(User $user): array
{
    return [
        'id'           => $user->id,
        'name'         => $user->name,
        'email'        => $user->email,
        'role'         => $user->role,
        'onboarded_at' => optional($user->onboarded_at)?->toIso8601String(),
    ];
}

public function me(Request $request): JsonResponse
{
    return response()->json(['user' => $this->userPayload($request->user())]);
}

public function completeOnboarding(Request $request): JsonResponse
{
    $user = $request->user();
    $user->onboarded_at = now();
    $user->save();
    return response()->json(['user' => $this->userPayload($user)]);
}
```

### Route — routes/api.php
```php
Route::post('/onboarding/complete', [AuthController::class, 'completeOnboarding'])
    ->middleware('auth:api');
```

---

## Phase 2: Frontend — Auth Composable Extension

### useAuth.ts — add to user type + completeOnboarding()
```typescript
// Add to user type
interface User {
  id: number
  name: string
  email: string
  role: string
  onboarded_at?: string | null  // ← add this
}

// Add function
async function completeOnboarding() {
  try {
    const res = await fetch('/api/onboarding/complete', {
      method: 'POST',
      headers: { Authorization: `Bearer ${token.value}`, Accept: 'application/json' },
    })
    if (res.ok) {
      const data = await res.json()
      setUser(data.user)  // updates onboarded_at locally
    }
  } catch { /* silent — tour already closed visually */ }
}
```

---

## Phase 3: Tour State Machine

### src/composables/useTour.ts
```typescript
import { ref, computed } from 'vue'
import { useAuth } from '@/composables/useAuth'
import { steps, type TourStep } from '@/data/tourSteps'

const active = ref(false)
const stepIndex = ref(0)

export function useTour() {
  const { completeOnboarding } = useAuth()

  const currentStep = computed<TourStep | null>(() =>
    active.value ? steps[stepIndex.value] ?? null : null
  )
  const isFirst = computed(() => stepIndex.value === 0)
  const isLast  = computed(() => stepIndex.value === steps.length - 1)

  function start() { stepIndex.value = 0; active.value = true }
  function next()  { if (!isLast.value) stepIndex.value++ }
  function prev()  { if (!isFirst.value) stepIndex.value-- }
  function end()   { active.value = false; completeOnboarding() }

  return { active, stepIndex, steps, currentStep, isFirst, isLast, start, next, prev, skip: end, finish: end }
}
```

### src/data/tourSteps.ts
```typescript
export interface TourStep {
  target: string   // matches [data-tour="…"]
  title: string
  body: string
  placement?: 'top' | 'bottom' | 'left' | 'right'
}

export const steps: TourStep[] = [
  { target: 'brand-toggle',    title: 'Switch brands',       body: 'Toggle between AFG and Libertad Capital. Every setting, template, and GHL connection switches with it.', placement: 'right' },
  { target: 'email-settings',  title: 'Audience & offer',    body: 'Tell the AI who you\'re writing to and what you\'re offering. The more specific, the better the email.', placement: 'right' },
  { target: 'template-picker', title: 'Template type',       body: 'Pick the campaign type. Each type follows a distinct narrative arc (Welcome, Funded, Reminder, Renewal, Newsletter).', placement: 'right' },
  { target: 'generate',        title: 'Generate',            body: 'Hit Generate — the AI writes a full branded email in seconds. Regenerate to try another pass.', placement: 'top' },
  { target: 'quality-score',   title: 'Quality score',       body: 'Every email is scored for clarity, compliance, and tone. Open the coaching tips and apply them before sending.', placement: 'left' },
  { target: 'push-ghl',        title: 'Push to GoHighLevel', body: 'Push the finished email straight to GHL as a builder template — ready to use in campaigns.', placement: 'left' },
  { target: 'nav-planner',     title: 'Campaign Planner',    body: 'Need a full drip sequence? The Planner builds a multi-email campaign with timing in five steps.', placement: 'right' },
  { target: 'nav-drafts',      title: 'Drafts & approval',   body: 'Save drafts for review. Admins approve or reject before anything goes live.', placement: 'right' },
  { target: 'nav-help',        title: 'Help Center',         body: 'All documentation lives here — search by keyword or browse by category.', placement: 'right' },
]
```

---

## Phase 4: GuidedTour Component

### src/components/onboarding/GuidedTour.vue
```vue
<script setup lang="ts">
import { ref, watch, onMounted, onBeforeUnmount, Teleport } from 'vue'
import { useTour } from '@/composables/useTour'

const tour = useTour()
const box = ref({ top: 0, left: 0, width: 0, height: 0 })
const PADDING = 8

function getTargetRect(target: string) {
  const el = document.querySelector(`[data-tour="${target}"]`)
  if (!el) return null
  const r = el.getBoundingClientRect()
  return { top: r.top - PADDING, left: r.left - PADDING, width: r.width + PADDING * 2, height: r.height + PADDING * 2 }
}

function reposition() {
  if (!tour.currentStep.value) return
  const rect = getTargetRect(tour.currentStep.value.target)
  if (rect) box.value = rect
}

watch(() => tour.currentStep.value, (step) => {
  if (!step) return
  const el = document.querySelector(`[data-tour="${step.target}"]`)
  el?.scrollIntoView({ behavior: 'smooth', block: 'center' })
  requestAnimationFrame(reposition)
})

function onKey(e: KeyboardEvent) {
  if (!tour.active.value) return
  if (e.key === 'Escape')      tour.skip()
  if (e.key === 'ArrowRight')  tour.next()
  if (e.key === 'ArrowLeft')   tour.prev()
}

onMounted(()    => { window.addEventListener('keydown', onKey); window.addEventListener('resize', reposition) })
onBeforeUnmount(() => { window.removeEventListener('keydown', onKey); window.removeEventListener('resize', reposition) })
</script>

<template>
  <Teleport to="body">
    <div v-if="tour.active.value" class="tour-overlay" aria-live="polite" aria-atomic="true">
      <!-- Spotlight cutout -->
      <div
        class="tour-spotlight"
        :style="{
          top:    box.top    + 'px',
          left:   box.left   + 'px',
          width:  box.width  + 'px',
          height: box.height + 'px',
        }"
      />

      <!-- Tooltip card -->
      <div class="tour-card" :style="{ top: (box.top + box.height + 16) + 'px', left: box.left + 'px' }">
        <p class="tour-step-label">{{ tour.stepIndex.value + 1 }} / {{ tour.steps.length }}</p>
        <h3 class="tour-title">{{ tour.currentStep.value?.title }}</h3>
        <p class="tour-body">{{ tour.currentStep.value?.body }}</p>

        <div class="tour-dots">
          <span v-for="(_, i) in tour.steps" :key="i" class="tour-dot" :class="{ active: i === tour.stepIndex.value }" />
        </div>

        <div class="tour-actions">
          <button type="button" class="btn-ghost text-xs" @click="tour.skip()">Skip</button>
          <div class="flex gap-2">
            <button v-if="!tour.isFirst.value" type="button" class="btn-ghost text-xs" @click="tour.prev()">Back</button>
            <button v-if="!tour.isLast.value" type="button" class="btn-primary text-xs" @click="tour.next()">Next</button>
            <button v-else type="button" class="btn-primary text-xs" @click="tour.finish()">Done</button>
          </div>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.tour-overlay { position: fixed; inset: 0; z-index: 9000; pointer-events: none; }

.tour-spotlight {
  position: absolute;
  border-radius: 10px;
  box-shadow: 0 0 0 9999px rgba(15, 23, 42, 0.62);
  pointer-events: none;
  transition: top 280ms ease, left 280ms ease, width 280ms ease, height 280ms ease;
}

.tour-card {
  position: absolute;
  background: #fff;
  border-radius: 14px;
  padding: 20px 22px 16px;
  max-width: 320px;
  box-shadow: 0 8px 32px rgba(0,0,0,.18);
  pointer-events: all;
  animation: scaleIn 200ms ease;
}
.tour-step-label { font-size: 0.72rem; font-weight: 700; text-transform: uppercase; letter-spacing: .08em; color: #94a3b8; margin: 0 0 6px; }
.tour-title { font-size: 1rem; font-weight: 700; color: #0f172a; margin: 0 0 8px; }
.tour-body { font-size: 0.875rem; color: #475569; line-height: 1.55; margin: 0 0 14px; }

.tour-dots { display: flex; gap: 5px; margin-bottom: 14px; }
.tour-dot { width: 6px; height: 6px; border-radius: 50%; background: #e2e8f0; transition: background 200ms; }
.tour-dot.active { background: #0f172a; }

.tour-actions { display: flex; justify-content: space-between; align-items: center; }

@keyframes scaleIn {
  from { opacity: 0; transform: scale(.94); }
  to   { opacity: 1; transform: scale(1); }
}
</style>
```

---

## Phase 5: data-tour Anchors

Add `data-tour="<step-target>"` to the target elements in the app:

| Step target       | Element to annotate |
|-------------------|---------------------|
| `brand-toggle`    | Brand switcher button in AppLayout sidebar |
| `email-settings`  | Email settings form card/wrapper |
| `template-picker` | CampaignSettings / template select wrapper |
| `generate`        | GenerateButton component |
| `quality-score`   | QualityScore component root |
| `push-ghl`        | Output / ActionBar GHL push section |
| `nav-planner`     | Sidebar nav link to Planner |
| `nav-drafts`      | Sidebar nav link to Drafts |
| `nav-help`        | Sidebar nav link to Help |

Example in AppLayout.vue sidebar link:
```html
<RouterLink to="/dashboard/planner" data-tour="nav-planner">Planner</RouterLink>
```

Example in a component template:
```html
<div data-tour="email-settings">
  <!-- form content -->
</div>
```

---

## Phase 6: Auto-Start in App.vue

```vue
<script setup lang="ts">
import { watch } from 'vue'
import { useRouter } from 'vue-router'
import { useAuth } from '@/composables/useAuth'
import { useTour } from '@/composables/useTour'
import GuidedTour from '@/components/onboarding/GuidedTour.vue'

const { user } = useAuth()
const router = useRouter()
const tour = useTour()

// Auto-start for new users
watch(user, (u) => {
  if (u && u.onboarded_at == null) {
    if (router.currentRoute.value.name !== 'generator') {
      router.push({ name: 'generator' }).then(() => setTimeout(() => tour.start(), 400))
    } else {
      setTimeout(() => tour.start(), 400)
    }
  }
}, { once: true })
</script>

<template>
  <!-- existing app shell -->
  <GuidedTour />  <!-- mount in authenticated branch only -->
</template>
```

---

## Phase 7: Help Center

### Router entry (router/index.ts)
```typescript
import HelpView from '@/views/HelpView.vue'
// in routes array:
{ path: '/help', name: 'help', component: HelpView, meta: { requiresAuth: true } }
```

### src/data/helpContent.ts — Article structure
```typescript
export type HelpCategory = 'getting-started' | 'features' | 'integrations' | 'reference' | 'troubleshooting'

export interface HelpArticle {
  id: string
  title: string
  category: HelpCategory
  summary: string
  keywords: string[]
  body: string  // trusted HTML authored in-repo
}

export const HELP_CATEGORIES: { id: HelpCategory; label: string }[] = [
  { id: 'getting-started', label: 'Getting started' },
  { id: 'features',        label: 'Features' },
  { id: 'integrations',    label: 'Integrations' },
  { id: 'reference',       label: 'Reference' },
  { id: 'troubleshooting', label: 'Troubleshooting' },
]

export const helpArticles: HelpArticle[] = [
  {
    id: 'overview',
    title: 'Welcome & overview',
    category: 'getting-started',
    summary: 'What the tool does and how a campaign flows from idea to sent email.',
    keywords: ['overview', 'start', 'intro'],
    body: `
      <h2>What this tool does</h2>
      <p>…</p>
    `,
  },
  // Add one entry per topic. HTML is trusted (internal audience).
]

export function searchArticles(query: string): HelpArticle[] {
  const q = query.trim().toLowerCase()
  if (!q) return helpArticles
  return helpArticles.filter((a) => {
    const hay = `${a.title} ${a.summary} ${a.keywords.join(' ')} ${a.body}`.toLowerCase()
    return hay.includes(q)
  })
}
```

### HelpView.vue — Two-pane layout (sidebar + reader)
```vue
<script setup lang="ts">
import { computed, ref } from 'vue'
import { HELP_CATEGORIES, helpArticles, searchArticles, type HelpArticle } from '@/data/helpContent'

const query = ref('')
const selectedId = ref<string>(helpArticles[0]?.id ?? '')

const results  = computed(() => searchArticles(query.value))
const grouped  = computed(() =>
  HELP_CATEGORIES
    .map((c) => ({ ...c, items: results.value.filter((a) => a.category === c.id) }))
    .filter((g) => g.items.length > 0)
)
const selected = computed<HelpArticle | null>(
  () => helpArticles.find((a) => a.id === selectedId.value) ?? results.value[0] ?? null
)
</script>

<template>
  <div class="help-page">
    <header class="mb-6">
      <h1 class="font-display text-2xl font-bold">Help Center</h1>
    </header>

    <div class="help-grid">
      <aside class="help-nav card">
        <input v-model="query" type="search" class="input mb-3" placeholder="Search help…" />
        <nav>
          <div v-for="g in grouped" :key="g.id">
            <p class="section-label">{{ g.label }}</p>
            <button
              v-for="a in g.items" :key="a.id" type="button"
              class="help-item" :class="{ 'is-active': a.id === selected?.id }"
              @click="selectedId = a.id"
            >{{ a.title }}</button>
          </div>
        </nav>
      </aside>

      <!-- Content is static, authored in-repo (trusted) -->
      <article class="help-reader card" :key="selected?.id">
        <template v-if="selected">
          <h2>{{ selected.title }}</h2>
          <p class="text-text-muted text-sm mb-4">{{ selected.summary }}</p>
          <div class="help-prose" v-html="selected.body" />
        </template>
      </article>
    </div>
  </div>
</template>
```

Add global (un-scoped) `.help-prose` typography styles so `v-html` content is styled:
```css
/* un-scoped — needed because v-html content is outside scoped styles */
.help-prose { color: var(--ink-light); font-size: 0.95rem; line-height: 1.7; }
.help-prose h2 { font-size: 1.15rem; font-weight: 700; margin: 26px 0 10px; }
.help-prose h3 { font-size: 1rem; font-weight: 700; margin: 20px 0 8px; }
.help-prose p  { margin: 0 0 12px; }
.help-prose ul, .help-prose ol { margin: 0 0 14px; padding-left: 22px; }
.help-prose code { font-family: monospace; font-size: 0.85em; background: var(--paper); border: 1px solid var(--border); border-radius: 5px; padding: 1px 5px; }
.help-prose a { color: var(--accent, #3b82f6); text-decoration: underline; }
```

---

## Phase 8: Replay From Profile

In ProfileView.vue or any settings page:
```vue
<script setup lang="ts">
import { useRouter } from 'vue-router'
import { useTour } from '@/composables/useTour'

const router = useRouter()
const tour = useTour()

async function replayTour() {
  if (router.currentRoute.value.name !== 'generator') await router.push({ name: 'generator' })
  setTimeout(() => tour.start(), 400)
}
</script>

<template>
  <button type="button" class="btn-primary" @click="replayTour">Replay product tour</button>
  <RouterLink to="/help" class="btn-ghost">Open Help Center</RouterLink>
</template>
```

---

## Checklist

- [ ] Migration created + run (`php artisan migrate`)
- [ ] `User::$casts` has `'onboarded_at' => 'datetime'`
- [ ] `AuthController::userPayload()` includes `onboarded_at`
- [ ] `POST /api/onboarding/complete` route added
- [ ] `useAuth` user type + `completeOnboarding()` updated
- [ ] `useTour.ts` + `tourSteps.ts` created
- [ ] `GuidedTour.vue` mounted in App.vue (authenticated branch only)
- [ ] Auto-start watch in App.vue (`onboarded_at == null` check)
- [ ] All `data-tour` attrs on target elements
- [ ] Router has `/help` → `HelpView`
- [ ] `helpContent.ts` has articles for all major features
- [ ] `.help-prose` styles are **un-scoped** (so `v-html` content is styled)
- [ ] Replay button in Profile links back to tour

## Key Design Decisions

**Spotlight technique**: `box-shadow: 0 0 0 9999px rgba(15,23,42,.62)` on a positioned element creates the dim overlay with a transparent cutout. Glide between steps by transitioning `top/left/width/height` on that element (280ms ease).

**No tour library**: Uses only Vue 3 + Teleport + CSS. Zero new dependencies.

**Sticky `active` ref outside composable factory**: `const active = ref(false)` declared at module scope so all calls to `useTour()` share the same reactive instance (singleton pattern without Pinia).

**HTML docs vs markdown**: Articles are trusted HTML authored in-repo. Avoids a markdown-to-HTML runtime library while still supporting rich formatting.

**`onboarded_at == null` not `!onboarded_at`**: Important distinction — falsy check would also trigger on `0`, empty string. Strict `== null` covers both `null` and `undefined`.
