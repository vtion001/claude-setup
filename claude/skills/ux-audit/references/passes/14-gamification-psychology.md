# Pass 14: Gamification & Reward Psychology

Conditional pass — only scored when the app has points, badges, levels, streaks, or
leaderboards. If Tier 1 detects none of these, mark the pass **N/A** (excluded from the
DQS weighted average, not scored as a 1) rather than penalizing a non-gamified app for
lacking gamification.

## Tier 1: Automated Checks

### 14.1 Gamification Element Detection

```javascript
(() => {
  const results = { detected: [], issues: [] };
  const bodyText = (document.body.innerText || '').toLowerCase();

  const signals = {
    points: /\b\d[\d,]*\s*(pts|points)\b/i.test(bodyText) || !!document.querySelector('[class*="points"], [class*="Points"]'),
    badges: /\bbadges?\b/i.test(bodyText) || !!document.querySelector('[class*="badge"], [class*="Badge"], [class*="achievement"]'),
    levels: /\blevel\s*\d+\b/i.test(bodyText) || !!document.querySelector('[class*="level"], [class*="Level"]'),
    streaks: /\bstreaks?\b/i.test(bodyText) || !!document.querySelector('[class*="streak"]'),
    leaderboard: /\b(leaderboard|top\s+performers|rankings?)\b/i.test(bodyText) || !!document.querySelector('[class*="leaderboard"], [class*="ranking"]'),
    progressBars: document.querySelectorAll('[role="progressbar"], progress, [class*="progress-bar"], [class*="progressBar"]').length
  };

  results.detected = Object.entries(signals).filter(([, v]) => v).map(([k]) => k);
  results.isGamifiedPage = results.detected.length > 0;
  results.stats = signals;

  return results;
})()
```

### 14.2 Points/Goal Framing — Distance-to-Goal vs. Progress-Made

```javascript
(() => {
  const results = { issues: [], stats: {} };
  const candidates = Array.from(document.querySelectorAll('[class*="progress"], [class*="points"], [class*="level"]'));
  const remainingFraming = [];
  const completedFraming = [];

  candidates.forEach(el => {
    const text = (el.textContent || '').trim();
    if (!text || text.length > 120) return;
    // "2 left", "need 50 more", "X to go" = remaining-framing (weaker per Goal-Gradient research)
    if (/\b(left|remaining|to go|more to)\b/i.test(text)) remainingFraming.push(text.substring(0, 60));
    // "8 of 10", "80% complete", "X / Y" = progress-made framing (stronger)
    if (/\b(of|\/)\s*\d+|%\s*(complete|done)\b/i.test(text)) completedFraming.push(text.substring(0, 60));
  });

  results.stats = { remainingFramingCount: remainingFraming.length, completedFramingCount: completedFraming.length };
  results.issues = remainingFraming.length > completedFraming.length
    ? [{ type: 'remaining-framing-dominant', examples: remainingFraming.slice(0, 5),
         message: 'More copy frames progress as "how much is left" than "how far you\'ve come." The Goal-Gradient Effect research shows progress-made framing ("8 of 10 done") outperforms remaining framing ("2 left") for motivation.' }]
    : [];

  return results;
})()
```

### 14.3 Leaderboard Scope Check

```javascript
(() => {
  const results = { issues: [], stats: {} };
  const board = document.querySelector('[class*="leaderboard"], [class*="ranking"]');
  if (!board) return { ...results, present: false };

  const bodyText = (document.body.innerText || '').toLowerCase();
  const hasSegmentFilter = /\b(department|team|group|division|cohort|this month|weekly|monthly)\b/i.test(bodyText);
  const rows = board.querySelectorAll('[class*="row"], li, tr').length;

  results.stats = { present: true, rowCount: rows, hasSegmentFilterCopy: hasSegmentFilter };
  if (rows > 20 && !hasSegmentFilter) {
    results.issues.push({
      type: 'unsegmented-large-leaderboard',
      rowCount: rows,
      message: `Leaderboard shows ${rows}+ entries with no visible department/team/period filter. Social Comparison Theory research: large global rankings demotivate everyone outside the top few because the gap no longer feels closable. Peer-cohort segmentation (department, team, time period) keeps the comparison motivating for more users.`
    });
  }
  return results;
})()
```

## Tier 2: AI Judgment

Only run these questions on pages where Tier 1 set `isGamifiedPage: true`.

### Goal-Gradient Effect (Points & Progress)
1. Is the user's current progress toward the next reward/level/goal visible at the point of decision (not buried on a separate stats page)?
2. Where progress is shown, is it framed as distance covered ("8 of 10", "60% there") rather than distance remaining ("2 left")? Both can appear, but which dominates?
3. Is the *next* achievable milestone always visible, not just the final one? (A single distant goal is less motivating than a visible next step.)

### Badge & Achievement Design
4. Do badges feel earned (tied to a real, specific accomplishment) or would most users get most badges automatically within days? **Badge inflation is a named failure mode** — trivially-earned badges lose their status-signaling value and can *lower* perceived product quality.
5. Is there a clear, honest description of what each badge requires, shown before it's earned (so it can function as a goal, not just a surprise)?
6. Do badges/achievements ever get re-awarded or duplicated in a way that cheapens them?

### Leaderboard & Social Comparison
7. Is ranking segmented (department/team/role/time-period) rather than one global all-time list? A single global leaderboard with more than ~20-30 participants reliably demotivates everyone below the visible top tier.
8. Does the current user's own position stand out clearly, even if they're not in the top N (e.g. "You: #47" pinned/sticky), rather than requiring them to scroll to find themselves?
9. Is there a visible "this is closable" signal — e.g. points-to-next-rank — rather than just an absolute position?

### Overjustification Risk
10. Are points/rewards being attached to behaviors people already do willingly (e.g. helping a coworker, posting a genuine celebration)? Research on the Overjustification Effect: bolting an external reward onto an already-intrinsically-motivated action can *reduce* long-term engagement with that action once the reward is removed or becomes routine. This is a design judgment call, not an automatic fail — flag it for awareness, not as a hard violation.
11. Do reward mechanics ever feel manipulative or compulsion-driven (variable-ratio "gambling" patterns, urgency countdowns on point redemption, streak-loss guilt messaging)? These push into **dark-pattern** territory — cross-reference with Pass 10.

## Scoring Criteria

| Score | Criteria |
|-------|---------|
| N/A | No gamification elements detected on any audited page — pass excluded from DQS. |
| 5 | Progress-made framing dominates. Badges are specific, honest, and non-trivial to earn. Leaderboard is segmented with the current user's position always visible. No overjustification or dark-pattern reward mechanics. |
| 4 | Mostly progress-made framing (1-2 remaining-framing instances). Badges mostly meaningful. Leaderboard segmented but user's own position isn't pinned/highlighted. |
| 3 | Framing is a mix with no clear dominant pattern. Some badges feel trivial. Leaderboard exists but segmentation is unclear or hard to find. |
| 2 | Remaining-framing dominates ("X left" everywhere). Badge inflation apparent (most badges earned within days). Leaderboard is a single unsegmented global list with 20+ visible entries. |
| 1 | No visible progress framing at all. Badges are decorative/meaningless. Global leaderboard with no segmentation and no way to find your own rank. Reward mechanics show manipulative/compulsion-driven patterns. |

## Common Fixes

### Progress-made framing
```
Before: "50 points until your next reward"
After:  "150 / 200 points — almost there"
```
Prefer showing both the fraction/percentage AND a short "almost there" style nudge over a pure countdown.

### Leaderboard segmentation
```jsx
// Before: one global list
<Leaderboard entries={allUsers} />

// After: default to the user's own peer group, with an explicit way to widen scope
<Leaderboard
  entries={sameDepartmentUsers}
  filters={["My Department", "This Month", "All Time", "Company-wide"]}
  pinCurrentUser
/>
```

### Badge honesty
Show the requirement text on locked badges instead of a generic "???" — e.g. "Complete 5 challenges this month" rather than a mystery silhouette. Mystery-box framing is fine for *rewards*, but badges function as goals, not surprises — users need to know what they're working toward.
